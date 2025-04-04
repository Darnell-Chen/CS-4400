-- CS4400: Introduction to Database Systems: Monday, March 3, 2025
-- Simple Airline Management System Course Project Mechanics [TEMPLATE] (v0)
-- Views, Functions & Stored Procedures

/* This is a standard preamble for most of our scripts.  The intent is to establish
a consistent environment for the database behavior. */
set global transaction isolation level serializable;
set global SQL_MODE = 'ANSI,TRADITIONAL';
set names utf8mb4;
set SQL_SAFE_UPDATES = 0;

set @thisDatabase = 'flight_tracking';
use flight_tracking;
-- -----------------------------------------------------------------------------
-- stored procedures and views
-- -----------------------------------------------------------------------------
/* Standard Procedure: If one or more of the necessary conditions for a procedure to
be executed is false, then simply have the procedure halt execution without changing
the database state. Do NOT display any error messages, etc. */

-- [_] supporting functions, views and stored procedures
-- -----------------------------------------------------------------------------
/* Helpful library capabilities to simplify the implementation of the required
views and procedures. */
-- -----------------------------------------------------------------------------
drop function if exists leg_time;
delimiter //
create function leg_time (ip_distance integer, ip_speed integer)
	returns time reads sql data
begin
	declare total_time decimal(10,2);
    declare hours, minutes integer default 0;
    set total_time = ip_distance / ip_speed;
    set hours = truncate(total_time, 0);
    set minutes = truncate((total_time - hours) * 60, 0);
    return maketime(hours, minutes, 0);
end //
delimiter ;

-- [1] add_airplane()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new airplane.  A new airplane must be sponsored
by an existing airline, and must have a unique tail number for that airline.
username.  An airplane must also have a non-zero seat capacity and speed. An airplane
might also have other factors depending on it's type, like the model and the engine.  
Finally, an airplane must have a new and database-wide unique location
since it will be used to carry passengers. */
-- -----------------------------------------------------------------------------

-- Ensure that the plane type is valid: Boeing, Airbus, or neither
-- Ensure that the type-specific attributes are accurate for the type
-- Ensure that the airplane and location values are new and unique
-- Add airplane and location into respective tables

DROP PROCEDURE IF EXISTS add_airplane;
DELIMITER //

CREATE PROCEDURE add_airplane (
    IN ip_airlineID VARCHAR(50),
    IN ip_tail_num VARCHAR(50),
    IN ip_seat_capacity INTEGER,
    IN ip_speed INTEGER,
    IN ip_locationID VARCHAR(50),
    IN ip_plane_type VARCHAR(100),
    IN ip_maintenanced BOOLEAN,
    IN ip_model VARCHAR(50),
    IN ip_neo BOOLEAN
)
sp_main: BEGIN

    IF NOT EXISTS (SELECT 1 FROM airline WHERE airlineID = ip_airlineID) THEN
        LEAVE sp_main;
    END IF;

    IF ip_tail_num IS NULL OR ip_tail_num = '' THEN
         LEAVE sp_main;
    END IF;

    IF EXISTS (SELECT 1 FROM airplane WHERE airlineID = ip_airlineID AND tail_num = ip_tail_num) THEN
        LEAVE sp_main;
    END IF;

    IF ip_seat_capacity IS NULL OR ip_seat_capacity <= 0 THEN
        LEAVE sp_main;
    END IF;

    IF ip_speed IS NULL OR ip_speed <= 0 THEN
        LEAVE sp_main;
    END IF;

    IF ip_locationID IS NULL OR ip_locationID = '' THEN
        LEAVE sp_main;
    END IF;

    IF EXISTS (SELECT 1 FROM location WHERE locationID = ip_locationID) THEN
        LEAVE sp_main;
    END IF;

    IF ip_plane_type = 'Boeing' THEN
        IF ip_neo IS NOT NULL THEN
            LEAVE sp_main;
        END IF;
    ELSEIF ip_plane_type = 'Airbus' THEN
        IF ip_model IS NOT NULL THEN
            LEAVE sp_main;
        END IF;
        IF ip_maintenanced IS NOT NULL THEN
            LEAVE sp_main;
        END IF;
    ELSE
        IF ip_model IS NOT NULL OR ip_neo IS NOT NULL OR ip_maintenanced IS NOT NULL THEN
            LEAVE sp_main;
        END IF;
    END IF;

    START TRANSACTION;

    INSERT INTO location (locationID) VALUES (ip_locationID);

    INSERT INTO airplane (airlineID, tail_num, seat_capacity, speed, locationID, plane_type, maintenanced, model, neo)
    VALUES (ip_airlineID, ip_tail_num, ip_seat_capacity, ip_speed, ip_locationID, ip_plane_type, ip_maintenanced, ip_model, ip_neo);

    COMMIT;

END //
DELIMITER ;
-- [2] add_airport()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new airport.  A new airport must have a unique
identifier along with a new and database-wide unique location if it will be used
to support airplane takeoffs and landings.  An airport may have a longer, more
descriptive name.  An airport must also have a city, state, and country designation. */
-- -----------------------------------------------------------------------------
	-- Ensure that the airport and location values are new and unique
    -- Add airport and location into respective tables
DROP PROCEDURE IF EXISTS add_airport;
DELIMITER //
CREATE PROCEDURE add_airport (
    IN ip_airportID CHAR(3),
    IN ip_airport_name VARCHAR(200),
    IN ip_city VARCHAR(100),
    IN ip_state VARCHAR(100),
    IN ip_country CHAR(3),
    IN ip_locationID VARCHAR(50)
)
sp_main: BEGIN
    DECLARE actual_locationID VARCHAR(50) DEFAULT NULL;

    IF ip_airportID IS NULL OR ip_airportID = '' OR
       ip_airport_name IS NULL OR ip_airport_name = '' OR
       ip_city IS NULL OR ip_city = '' OR
       ip_state IS NULL OR ip_state = '' OR
       ip_country IS NULL OR ip_country = '' THEN
        LEAVE sp_main;
    END IF;

    IF EXISTS (SELECT 1 FROM airport WHERE BINARY airportID = BINARY ip_airportID) THEN
        LEAVE sp_main;
    END IF;

    IF ip_locationID IS NOT NULL AND ip_locationID <> '' THEN
        IF EXISTS (SELECT 1 FROM location WHERE BINARY locationID = BINARY ip_locationID) THEN
            LEAVE sp_main;
        END IF;
        SET actual_locationID = ip_locationID;
    END IF;

    START TRANSACTION;

    IF actual_locationID IS NOT NULL THEN
        INSERT INTO location (locationID) VALUES (actual_locationID);
    END IF;

    INSERT INTO airport (airportID, airport_name, city, state, country, locationID)
    VALUES (ip_airportID, ip_airport_name, ip_city, ip_state, ip_country, actual_locationID);

    COMMIT;

END //
DELIMITER ;

-- [3] add_person()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new person.  A new person must reference a unique
identifier along with a database-wide unique location used to determine where the
person is currently located: either at an airport, or on an airplane, at any given
time.  A person must have a first name, and might also have a last name.

A person can hold a pilot role or a passenger role (exclusively).  As a pilot,
a person must have a tax identifier to receive pay, and an experience level.  As a
passenger, a person will have some amount of frequent flyer miles, along with a
certain amount of funds needed to purchase tickets for flights. */
-- -----------------------------------------------------------------------------

-- Ensure that the location is valid
-- Ensure that the persion ID is unique
-- Ensure that the person is a pilot or passenger
-- Add them to the person table as well as the table of their respective role

DROP PROCEDURE IF EXISTS add_person;
DELIMITER //

CREATE PROCEDURE add_person (
    IN ip_personID VARCHAR(50),
    IN ip_first_name VARCHAR(100),
    IN ip_last_name VARCHAR(100),
    IN ip_locationID VARCHAR(50),
    IN ip_taxID VARCHAR(50),
    IN ip_experience INTEGER,
    IN ip_miles INTEGER,
    IN ip_funds INTEGER
)
sp_main: BEGIN

    IF ip_personID IS NULL OR ip_personID = '' OR
       ip_first_name IS NULL OR ip_first_name = '' OR
       ip_locationID IS NULL OR ip_locationID = '' THEN
        LEAVE sp_main;
    END IF;

    IF EXISTS (SELECT 1 FROM person WHERE BINARY personID = BINARY ip_personID) THEN
        LEAVE sp_main;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM location WHERE BINARY locationID = BINARY ip_locationID) THEN
        LEAVE sp_main;
    END IF;

    IF (ip_taxID IS NOT NULL AND ip_experience IS NOT NULL) THEN
        IF (ip_miles IS NOT NULL OR ip_funds IS NOT NULL) THEN
            LEAVE sp_main;
        END IF;

        IF ip_experience < 0 THEN
            LEAVE sp_main;
        END IF;

        IF ip_taxID = '' THEN
             LEAVE sp_main;
        END IF;

        IF ip_taxID NOT LIKE '___-__-____' THEN
            LEAVE sp_main;
        END IF;

        IF EXISTS (SELECT 1 FROM pilot WHERE taxID = ip_taxID) THEN
            LEAVE sp_main;
        END IF;

        START TRANSACTION;
        INSERT INTO person (personID, first_name, last_name, locationID)
        VALUES (ip_personID, ip_first_name, ip_last_name, ip_locationID);

        INSERT INTO pilot (personID, taxID, experience, commanding_flight)
        VALUES (ip_personID, ip_taxID, ip_experience, NULL);
        COMMIT;

    ELSEIF (ip_miles IS NOT NULL AND ip_funds IS NOT NULL) THEN
        IF (ip_taxID IS NOT NULL OR ip_experience IS NOT NULL) THEN
            LEAVE sp_main;
        END IF;

        IF ip_miles < 0 OR ip_funds < 0 THEN
             LEAVE sp_main;
        END IF;

        START TRANSACTION;
        INSERT INTO person (personID, first_name, last_name, locationID)
        VALUES (ip_personID, ip_first_name, ip_last_name, ip_locationID);

        INSERT INTO passenger (personID, miles, funds)
        VALUES (ip_personID, ip_miles, ip_funds);
        COMMIT;

    ELSE
        LEAVE sp_main;
    END IF;

END //
DELIMITER ;

-- [4] grant_or_revoke_pilot_license()
-- -----------------------------------------------------------------------------
/* This stored procedure inverts the status of a pilot license.  If the license
doesn't exist, it must be created; and, if it aready exists, then it must be removed. */
-- -----------------------------------------------------------------------------
-- Ensure that the person is a valid pilot
-- If license exists, delete it, otherwise add the license

DROP PROCEDURE IF EXISTS grant_or_revoke_pilot_license;
DELIMITER //

CREATE PROCEDURE grant_or_revoke_pilot_license (
    IN ip_personID VARCHAR(50),
    IN ip_license VARCHAR(100)
)
sp_main: BEGIN
    DECLARE v_license_exists INT DEFAULT 0;

    IF ip_personID IS NULL OR ip_personID = '' THEN
        LEAVE sp_main;
    END IF;

    IF ip_license IS NULL OR ip_license = '' THEN
        LEAVE sp_main;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pilot WHERE BINARY personID = BINARY ip_personID) THEN
        LEAVE sp_main;
    END IF;

    SELECT COUNT(*) INTO v_license_exists
    FROM pilot_licenses
    WHERE BINARY personID = BINARY ip_personID AND BINARY license = BINARY ip_license;

    IF v_license_exists > 0 THEN
        DELETE FROM pilot_licenses
        WHERE BINARY personID = BINARY ip_personID AND BINARY license = BINARY ip_license;
    ELSE
        INSERT INTO pilot_licenses (personID, license)
        VALUES (ip_personID, ip_license);
    END IF;

END //
DELIMITER ;

-- [5] offer_flight()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new flight.  The flight can be defined before
an airplane has been assigned for support, but it must have a valid route.  And
the airplane, if designated, must not be in use by another flight.  The flight
can be started at any valid location along the route except for the final stop,
and it will begin on the ground.  You must also include when the flight will
takeoff along with its cost. */
-- -----------------------------------------------------------------------------

-- Ensure that the airplane exists
-- Ensure that the route exists
-- Ensure that the progress is less than the length of the route
-- Create the flight with the airplane starting in on the ground
DROP PROCEDURE IF EXISTS offer_flight;
DELIMITER //

CREATE PROCEDURE offer_flight (
    IN ip_flightID VARCHAR(50),
    IN ip_routeID VARCHAR(50),
    IN ip_support_airline VARCHAR(50),
    IN ip_support_tail VARCHAR(50),
    IN ip_progress INTEGER,
    IN ip_next_time TIME,
    IN ip_cost INTEGER
)
sp_main: BEGIN
    DECLARE v_route_exists INT DEFAULT 0;
    DECLARE v_plane_exists INT DEFAULT 0;
    DECLARE v_plane_assigned INT DEFAULT 0;
    DECLARE v_max_legs INT DEFAULT 0;

    IF ip_flightID IS NULL OR ip_flightID = '' THEN
        LEAVE sp_main;
    END IF;

    IF ip_routeID IS NULL OR ip_routeID = '' THEN
        LEAVE sp_main;
    END IF;

    START TRANSACTION;

    IF EXISTS (SELECT 1 FROM flight WHERE BINARY flightID = BINARY ip_flightID) THEN
        ROLLBACK;
        LEAVE sp_main;
    END IF;

    SELECT COUNT(*) INTO v_route_exists FROM route WHERE BINARY routeID = BINARY ip_routeID;
    IF v_route_exists = 0 THEN
        ROLLBACK;
        LEAVE sp_main;
    END IF;

    IF ip_support_airline IS NOT NULL AND ip_support_tail IS NOT NULL THEN
        IF ip_support_airline = '' OR ip_support_tail = '' THEN
             ROLLBACK;
             LEAVE sp_main;
        END IF;

        SELECT COUNT(*) INTO v_plane_exists FROM airplane
        WHERE BINARY airlineID = BINARY ip_support_airline AND BINARY tail_num = BINARY ip_support_tail;
        IF v_plane_exists = 0 THEN
            ROLLBACK;
            LEAVE sp_main;
        END IF;

        SELECT COUNT(*) INTO v_plane_assigned FROM flight
        WHERE BINARY support_airline = BINARY ip_support_airline AND BINARY support_tail = BINARY ip_support_tail;
        IF v_plane_assigned > 0 THEN
            ROLLBACK;
            LEAVE sp_main;
        END IF;
    ELSEIF ip_support_airline IS NOT NULL OR ip_support_tail IS NOT NULL THEN
         ROLLBACK;
         LEAVE sp_main;
    END IF;

    SELECT COUNT(*) INTO v_max_legs FROM route_path WHERE BINARY routeID = BINARY ip_routeID;
    IF ip_progress IS NULL OR ip_progress < 0 OR ip_progress >= v_max_legs THEN
       ROLLBACK;
       LEAVE sp_main;
    END IF;

    IF ip_cost IS NULL OR ip_cost < 0 THEN
       ROLLBACK;
       LEAVE sp_main;
    END IF;

    IF ip_next_time IS NULL THEN
        ROLLBACK;
        LEAVE sp_main;
    END IF;


    INSERT INTO flight (flightID, routeID, support_airline, support_tail, progress, airplane_status, next_time, cost)
    VALUES (ip_flightID, ip_routeID, ip_support_airline, ip_support_tail, ip_progress, 'on_ground', ip_next_time, ip_cost);

    COMMIT;

END //
DELIMITER ;

-- [6] flight_landing()
-- -----------------------------------------------------------------------------
/* This stored procedure updates the state for a flight landing at the next airport
along it's route.  The time for the flight should be moved one hour into the future
to allow for the flight to be checked, refueled, restocked, etc. for the next leg
of travel.  Also, the pilots of the flight should receive increased experience, and
the passengers should have their frequent flyer miles updated. */
-- -----------------------------------------------------------------------------
-- Ensure that the flight exists
-- Ensure that the flight is in the air
    
-- Increment the pilot's experience by 1
-- Increment the frequent flyer miles of all passengers on the plane
-- Update the status of the flight and increment the next time to 1 hour later
-- Hint: use addtime()

DROP PROCEDURE IF EXISTS flight_landing;
DELIMITER //

CREATE PROCEDURE flight_landing (IN ip_flightID VARCHAR(50))
sp_main: BEGIN
    DECLARE v_routeID VARCHAR(50);
    DECLARE v_progress INT;
    DECLARE v_airplane_status VARCHAR(100);
    DECLARE v_support_airline VARCHAR(50);
    DECLARE v_support_tail VARCHAR(50);
    DECLARE v_plane_intrinsic_loc VARCHAR(50);
    DECLARE v_legID VARCHAR(50);
    DECLARE v_distance INT;
    DECLARE v_arrival_airport CHAR(3);
    DECLARE v_arrival_loc VARCHAR(50);
    DECLARE v_current_next_time TIME;

    IF ip_flightID IS NULL OR ip_flightID = '' THEN
        LEAVE sp_main;
    END IF;

    START TRANSACTION;

    SELECT routeID, progress, airplane_status, support_airline, support_tail, next_time
    INTO v_routeID, v_progress, v_airplane_status, v_support_airline, v_support_tail, v_current_next_time
    FROM flight WHERE BINARY flightID = BINARY ip_flightID;

    IF v_routeID IS NULL THEN
        ROLLBACK;
        LEAVE sp_main;
    END IF;

    IF v_airplane_status <> 'in_flight' THEN
        ROLLBACK;
        LEAVE sp_main;
    END IF;

     IF v_current_next_time IS NULL THEN
        ROLLBACK;
        LEAVE sp_main;
    END IF;

    IF v_support_airline IS NULL OR v_support_tail IS NULL THEN
         ROLLBACK;
         LEAVE sp_main;
    END IF;

    SELECT locationID INTO v_plane_intrinsic_loc
    FROM airplane WHERE airlineID = v_support_airline AND tail_num = v_support_tail;
    IF v_plane_intrinsic_loc IS NULL THEN
        ROLLBACK;
        LEAVE sp_main;
    END IF;

    SELECT legID INTO v_legID
    FROM route_path WHERE routeID = v_routeID AND sequence = v_progress;

    IF v_legID IS NULL THEN
        ROLLBACK;
        LEAVE sp_main;
    END IF;

    SELECT distance, arrival INTO v_distance, v_arrival_airport
    FROM leg WHERE legID = v_legID;

    IF v_arrival_airport IS NULL THEN
        ROLLBACK;
        LEAVE sp_main;
    END IF;

    IF v_distance IS NULL OR v_distance < 0 THEN
        ROLLBACK;
        LEAVE sp_main;
    END IF;

    SELECT locationID INTO v_arrival_loc FROM airport WHERE airportID = v_arrival_airport;
    IF v_arrival_loc IS NULL THEN
        ROLLBACK;
        LEAVE sp_main;
    END IF;

    UPDATE pilot
    SET experience = experience + 1
    WHERE BINARY commanding_flight = BINARY ip_flightID;

    UPDATE passenger pas
    JOIN person per ON pas.personID = per.personID
    SET pas.miles = pas.miles + v_distance
    WHERE per.locationID = v_plane_intrinsic_loc;

    UPDATE flight
    SET airplane_status = 'on_ground',
        next_time = addtime(v_current_next_time, '01:00:00')
    WHERE BINARY flightID = BINARY ip_flightID;

    COMMIT;

END //
DELIMITER ;

-- [7] flight_takeoff()
-- -----------------------------------------------------------------------------
/* This stored procedure updates the state for a flight taking off from its current
airport towards the next airport along it's route.  The time for the next leg of
the flight must be calculated based on the distance and the speed of the airplane.
And we must also ensure that Airbus and general planes have at least one pilot
assigned, while Boeing must have a minimum of two pilots. If the flight cannot take
off because of a pilot shortage, then the flight must be delayed for 30 minutes. */
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS flight_takeoff;
DELIMITER //
CREATE PROCEDURE flight_takeoff (IN ip_flightID VARCHAR(50))
sp_main: BEGIN
    -- Declare necessary variables
    DECLARE v_airline VARCHAR(50);
    DECLARE v_tail VARCHAR(50);
    DECLARE v_progress INT;
    DECLARE v_status VARCHAR(50);
    DECLARE v_route VARCHAR(50);
    DECLARE v_departure_time TIME; -- Store the original takeoff time
    DECLARE v_total_legs INT;
    DECLARE v_plane_type VARCHAR(100);
    DECLARE v_speed INT;
    DECLARE v_pilot_count INT;
    DECLARE v_next_legID VARCHAR(50);
    DECLARE v_distance INT;
    DECLARE v_flight_seconds INT;
    DECLARE v_landing_time TIME;

    -- 1. Fetch core flight info
    SELECT support_airline, support_tail, progress, airplane_status, routeID, next_time
    INTO v_airline, v_tail, v_progress, v_status, v_route, v_departure_time
    FROM flight
    WHERE flightID = ip_flightID;

    IF v_airline IS NULL THEN -- If the SELECT INTO failed to find the flight
        LEAVE sp_main;
    END IF;

    IF v_status <> 'on_ground' THEN
        LEAVE sp_main;
    END IF;

    SELECT COUNT(*) INTO v_total_legs FROM route_path WHERE routeID = v_route;
    IF v_progress >= v_total_legs THEN
        LEAVE sp_main; -- No more legs to take off for
    END IF;

    SELECT plane_type, speed
    INTO v_plane_type, v_speed
    FROM airplane
    WHERE airlineID = v_airline AND tail_num = v_tail;

    IF v_plane_type IS NULL AND v_speed IS NULL THEN -- Check if SELECT INTO failed
         -- A more precise check might be needed if one could be null but not the other legitimately
         -- Or check FOUND_ROWS() immediately after SELECT INTO if preferred
        LEAVE sp_main;
    END IF;

    IF v_speed IS NULL OR v_speed <= 0 THEN
        LEAVE sp_main; -- Cannot calculate flight time with invalid speed
    END IF;

    SELECT COUNT(*) INTO v_pilot_count
    FROM pilot
    WHERE commanding_flight = ip_flightID;

    IF (v_plane_type = 'Boeing' AND v_pilot_count < 2) OR
       (v_plane_type <> 'Boeing' AND v_pilot_count < 1) THEN -- Includes NULL plane_type needing >=1 pilot
        -- Not enough pilots: delay the flight by 30 minutes and exit
        UPDATE flight
        SET next_time = ADDTIME(v_departure_time, '00:30:00')
        WHERE flightID = ip_flightID;
        LEAVE sp_main;
    END IF;

    SELECT legID INTO v_next_legID
    FROM route_path
    WHERE routeID = v_route AND sequence = v_progress + 1;

    IF v_next_legID IS NULL THEN
        LEAVE sp_main; -- Should not happen if progress check passed, but safety check
    END IF;

    SELECT distance INTO v_distance
    FROM leg
    WHERE legID = v_next_legID;

    IF v_distance IS NULL OR v_distance < 0 THEN -- Allowing 0 distance based on EC_FT_16 result
        LEAVE sp_main; -- Leg details missing or distance invalid
    END IF;


    -- Calculate landing time
    SET v_flight_seconds = (v_distance * 3600) DIV v_speed; -- Integer division for seconds
    SET v_landing_time = ADDTIME(v_departure_time, SEC_TO_TIME(v_flight_seconds));

    -- Update flight status, progress, and calculated next_time (landing time)
    UPDATE flight
    SET progress = v_progress + 1,
        airplane_status = 'in_flight',
        next_time = v_landing_time
    WHERE flightID = ip_flightID;

END //
DELIMITER ;

-- [8] passengers_board()
-- -----------------------------------------------------------------------------
/* This stored procedure updates the state for passengers getting on a flight at
its current airport.  The passengers must be at the same airport as the flight,
and the flight must be heading towards that passenger's desired destination.
Also, each passenger must have enough funds to cover the flight.  Finally, there
must be enough seats to accommodate all boarding passengers. */
-- -----------------------------------------------------------------------------
drop procedure if exists passengers_board;
DELIMITER //
CREATE PROCEDURE passengers_board(IN ip_flightID VARCHAR(50))
BEGIN
    -- Variable declarations
    DECLARE v_flight_departure CHAR(3);
    DECLARE v_flight_arrival CHAR(3);
    DECLARE v_flight_cost INT;
    DECLARE v_airplane_capacity INT;
    DECLARE v_current_passenger_count INT;
    DECLARE v_available_seats INT;
    DECLARE v_passengers_to_board_count INT;
    DECLARE v_boarding_location VARCHAR(50);
    DECLARE v_airplane_location VARCHAR(50);
    
    -- Temporary table to store passengers to board
    DROP TEMPORARY TABLE IF EXISTS temp_passengers_to_board;
    CREATE TEMPORARY TABLE temp_passengers_to_board (
        personID VARCHAR(50),
        funds INT,
        PRIMARY KEY (personID)
    );
    -- SECTION 1: Get flight and airplane information
    SELECT l.departure, l.arrival, f.cost, a.seat_capacity, ap.locationID, a.locationID
    INTO v_flight_departure, v_flight_arrival, v_flight_cost, v_airplane_capacity, 
         v_boarding_location, v_airplane_location
    FROM flight f
    JOIN route_path rp ON f.routeID = rp.routeID AND rp.sequence = f.progress + 1
    JOIN leg l ON rp.legID = l.legID
    JOIN airplane a ON f.support_airline = a.airlineID AND f.support_tail = a.tail_num
    JOIN airport ap ON l.departure = ap.airportID
    WHERE f.flightID = ip_flightID;
    
    -- SECTION 2: Calculate available seats
    SELECT COUNT(*) INTO v_current_passenger_count
    FROM person
    WHERE locationID = v_airplane_location;
    
    SET v_available_seats = v_airplane_capacity - v_current_passenger_count;
    
    -- SECTION 3: Identify eligible passengers
    SELECT COUNT(*) INTO v_passengers_to_board_count
    FROM passenger p
    JOIN person pe ON p.personID = pe.personID
    JOIN passenger_vacations pv ON p.personID = pv.personID
    WHERE pe.locationID = v_boarding_location
      AND pv.airportID = v_flight_arrival
      AND pv.sequence = 1
      AND p.funds >= v_flight_cost
      AND pe.locationID NOT LIKE 'plane_%';
    
    -- SECTION 4: Board passengers if conditions met
    IF v_available_seats > 0 AND v_passengers_to_board_count > 0 AND v_available_seats >= v_passengers_to_board_count THEN
        -- Insert eligible passengers into temp table ordered by funds
        INSERT INTO temp_passengers_to_board
        SELECT p.personID, p.funds
        FROM passenger p
        JOIN person pe ON p.personID = pe.personID
        JOIN passenger_vacations pv ON p.personID = pv.personID
        WHERE pe.locationID = v_boarding_location
          AND pv.airportID = v_flight_arrival
          AND p.funds >= v_flight_cost
	  AND pv.sequence = 1
          AND pe.locationID NOT LIKE 'plane_%'
        ORDER BY p.funds DESC
        LIMIT v_available_seats;
        
        -- Update passengers from temp table
        UPDATE person pe
        JOIN temp_passengers_to_board t ON pe.personID = t.personID
        SET pe.locationID = v_airplane_location;
        
        UPDATE passenger p
        JOIN temp_passengers_to_board t ON p.personID = t.personID
        SET p.funds = p.funds - v_flight_cost;
	
        
        -- Update airline revenue
        UPDATE airline a
        JOIN flight f ON a.airlineID = f.support_airline
        SET a.revenue = a.revenue + (v_flight_cost * 
            (SELECT COUNT(*) FROM temp_passengers_to_board))
        WHERE f.flightID = ip_flightID;
        
        DROP TEMPORARY TABLE IF EXISTS temp_passengers_to_board;
    END IF;
END //
DELIMITER ;

-- [9] passengers_disembark()
-- -----------------------------------------------------------------------------
/* This stored procedure updates the state for passengers getting off of a flight
at its current airport.  The passengers must be on that flight, and the flight must
be located at the destination airport as referenced by the ticket. */
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS passengers_disembark;
DELIMITER //
CREATE PROCEDURE passengers_disembark (IN ip_flightID VARCHAR(50))
sp_main: BEGIN
    DECLARE v_flight_arrival CHAR(3);
    DECLARE v_airplane_location VARCHAR(50);
    DECLARE v_disembark_location VARCHAR(50);
    DECLARE v_flight_status VARCHAR(100);
    DECLARE v_support_airline VARCHAR(50);
    DECLARE v_support_tail VARCHAR(50);

    -- Step 1: Ensure flight exists and is on the ground
    SELECT f.airplane_status, f.support_airline, f.support_tail
    INTO v_flight_status, v_support_airline, v_support_tail
    FROM flight f
    WHERE f.flightID = ip_flightID;

    IF v_flight_status IS NULL THEN
        LEAVE sp_main; -- Flight doesn't exist
    END IF;

    IF v_flight_status <> 'on_ground' THEN
        LEAVE sp_main; -- Flight not on ground
    END IF;

    -- Step 2: Get arrival airport from current leg (based on progress)
    SELECT l.arrival
    INTO v_flight_arrival
    FROM flight f
    JOIN route_path rp ON f.routeID = rp.routeID AND rp.sequence = f.progress
    JOIN leg l ON rp.legID = l.legID
    WHERE f.flightID = ip_flightID;

    -- Step 3: Get airplane's current location
    SELECT a.locationID INTO v_airplane_location
    FROM airplane a
    WHERE a.airlineID = v_support_airline AND a.tail_num = v_support_tail;

    -- Step 4: Get airport's locationID
    SELECT ap.locationID INTO v_disembark_location
    FROM airport ap
    WHERE ap.airportID = v_flight_arrival;

    -- Step 5: Identify passengers to disembark
    CREATE TEMPORARY TABLE IF NOT EXISTS temp_disembarking_passengers (
        personID VARCHAR(50) PRIMARY KEY
    );

    DELETE FROM temp_disembarking_passengers;

    INSERT INTO temp_disembarking_passengers
    SELECT p.personID
    FROM person p
    JOIN passenger_vacations pv ON p.personID = pv.personID
    WHERE p.locationID = v_airplane_location
      AND pv.sequence = 1
      AND pv.airportID = v_flight_arrival;

    -- Step 6: Move disembarking passengers to airport
    UPDATE person p
    JOIN temp_disembarking_passengers t ON p.personID = t.personID
    SET p.locationID = v_disembark_location;

    -- Step 7: Remove first vacation
    DELETE pv FROM passenger_vacations pv
    JOIN temp_disembarking_passengers t ON pv.personID = t.personID
    WHERE pv.sequence = 1;

    -- Step 8: Decrement remaining vacation sequences
    UPDATE passenger_vacations pv
    JOIN temp_disembarking_passengers t ON pv.personID = t.personID
    SET pv.sequence = pv.sequence - 1
    WHERE pv.sequence > 1;

    DROP TEMPORARY TABLE IF EXISTS temp_disembarking_passengers;
END;
//
DELIMITER ;

-- [10] assign_pilot()
-- -----------------------------------------------------------------------------
/* This stored procedure assigns a pilot as part of the flight crew for a given
flight.  The pilot being assigned must have a license for that type of airplane,
and must be at the same location as the flight.  Also, a pilot can only support
one flight (i.e. one airplane) at a time.  The pilot must be assigned to the flight
and have their location updated for the appropriate airplane. */
-- -----------------------------------------------------------------------------
drop procedure if exists assign_pilot;
delimiter //
create procedure assign_pilot (in ip_flightID varchar(50), in ip_personID varchar(50))
sp_main: begin

	declare t_support_airline varchar(50);
    declare t_support_tail varchar(50);
    declare t_plane_type varchar(50);
    declare person_location varchar(50);
    declare plane_location varchar(50);
    declare plane_leg varchar(50);
    declare plane_sequence int;
    declare plane_routeID varchar(50);
    declare plane_legID varchar(50);
    declare person_airport varchar(50);
    declare plane_airport varchar(50);
    declare first_leg varchar(50);

	-- Ensure the flight exists
    if ip_flightID not in (select flightID from flight) 
		then leave sp_main;
    end if;
    
    -- Ensure that the flight is on the ground
    if (select airplane_status from flight where flightID = ip_flightID) != 'on_ground' then
		leave sp_main;
	end if;
    
    
    -- Ensure that the flight has further legs to be flown
    if (select progress from flight where flightID = ip_flightID) >= (
		select sequence from route_path where routeID = (select routeID from flight where flightID = ip_flightID)
        order by sequence asc limit 1
	) then leave sp_main;
    end if;
    
    -- Ensure that the pilot exists and is not already assigned
    if ip_personID not in (select personID from pilot) or (select commanding_flight from pilot where personID = ip_personID) is not null then
		leave sp_main;
	end if;
    
	-- Ensure that the pilot has the appropriate license
	select support_airline, support_tail into t_support_airline, t_support_tail from flight where ip_flightID = flightID;
    select plane_type into t_plane_type from airplane where (tail_num = t_support_tail) and (airlineID = t_support_airline);
    
    if t_plane_type not in (select license from pilot_licenses where personID = ip_personID) then
		leave sp_main;
	end if;
    
    -- Ensure the pilot is located at the airport of the plane that is supporting the flight
    
    select locationID into person_location from person where personID = ip_personID;
    select locationID into plane_location from airplane where airlineID = t_support_airline and tail_num = t_support_tail;
    
    if person_location is null or plane_location is null then
		leave sp_main;
	end if;
    
    select progress into plane_sequence from flight where flightID = ip_flightID;
    select routeID into plane_routeID from flight where flightID = ip_flightID;
    
    set plane_sequence = plane_sequence + 1;
    
	select legID into plane_legID from route_path where sequence = plane_sequence and routeID = plane_routeID;
	select departure into plane_airport from leg where legID = plane_legID;
    
    select airportID into person_airport from airport where locationID = person_location;
    
    if (person_airport != plane_airport) then
		leave sp_main;
	end if;
    
    -- Assign the pilot to the flight and update their location to be on the plane
    
    update pilot
		set commanding_flight = ip_flightID
		where personID = ip_personID;
	
    update person
		set locationID = plane_location
        where personID = ip_personID;

end //
delimiter ;

-- [11] recycle_crew()
-- -----------------------------------------------------------------------------
/* This stored procedure releases the assignments for a given flight crew.  The
flight must have ended, and all passengers must have disembarked. */
-- -----------------------------------------------------------------------------
drop procedure if exists recycle_crew;
delimiter //
create procedure recycle_crew (in ip_flightID varchar(50))
sp_main: begin

	declare currStatus varchar(50);
    declare maxSequence int;
    declare currSequence int;
    declare currRouteID varchar(50);
    declare plane_location varchar(50);
    declare t_airlineID varchar(50);
    declare t_tail_num varchar(50);
    declare t_numSeated int;
    declare currAirport varchar(50);
    declare currLeg varchar(50);
    
	-- Ensure that the flight is on the ground
    select airplane_status into currStatus from flight where ip_flightID = flightID;
    if currStatus != 'on_ground' then 
		leave sp_main;
	end if;
    
    -- Ensure that the flight does not have any more legs
    select progress into currSequence from flight where ip_flightID = flightID;
    select routeID into currRouteID from flight where ip_flightID = flightID;
    select max(sequence) into maxSequence from route_path where routeID = currRouteID;
    
    if (currSequence < maxSequence) then
		leave sp_main;
	end if;
    
    -- Ensure that the flight is empty of passengers
    select support_airline into t_airlineID from flight where flightID = ip_flightID;
    select support_tail into t_tail_num from flight where flightID = ip_flightID;
    
    select locationID into plane_location from airplane where airlineID = t_airlineID and tail_num = t_tail_num;
    
    if plane_location is null then
		leave sp_main;
	end if;
    
    select count(*) into t_numSeated from 
    (select s.personID, p.locationID from passenger s join person p on p.personID = s.personID) as j 
    where j.locationID = plane_location;
    
    if t_numSeated > 0 then
		leave sp_main;
	end if;
    
	-- Move all pilots to the airport the plane of the flight is located at
    select legID into currLeg from route_path where routeID = currRouteID and sequence = currSequence;
    select arrival into currAirport from leg where legID = currLeg;
    
    
    update person p join pilot e on e.personID = p.personID
    set p.locationID = (select locationID from airport where airportID = currAirport)
    where commanding_flight = ip_flightID;
    
    -- Update assignments of all pilots
    update pilot
    set commanding_flight = null
    where commanding_flight = ip_flightID;
    

end //
delimiter ;

-- [12] retire_flight()
-- -----------------------------------------------------------------------------
/* This stored procedure removes a flight that has ended from the system.  The
flight must be on the ground, and either be at the start its route, or at the
end of its route.  And the flight must be empty - no pilots or passengers. */
-- -----------------------------------------------------------------------------
drop procedure if exists retire_flight;
delimiter //
create procedure retire_flight (in ip_flightID varchar(50))
sp_main: begin
declare v_airplane_status varchar(100);
    declare v_current_progress integer;
    declare v_routeID varchar(50);
    declare v_support_tail varchar(50);
    declare v_max_legs integer;
    declare v_people_on_board integer;
    declare v_plane_locationID varchar(50);

    select airplane_status, progress, routeID, support_tail
    into v_airplane_status, v_current_progress, v_routeID, v_support_tail
    from flight
    where flightID = ip_flightID;

    if v_routeID is null then
        leave sp_main;
    end if;

    if v_airplane_status <> 'on_ground' then
        leave sp_main;
    end if;

    select max(sequence) into v_max_legs from route_path where routeID = v_routeID;

    if not (v_current_progress = 0 or v_current_progress >= v_max_legs) then
        leave sp_main;
    end if;

    select locationID into v_plane_locationID
    from airplane
    where tail_num = v_support_tail;

    if v_plane_locationID is null then
        -- Cannot reliably check if people are on board if plane has no location
        -- Or, assume if plane has no location, no one is on it. Let's assume the former.
        -- If the design guarantees a plane always has a location when active, this check might be redundant.
        select count(*) into v_people_on_board from pilot where commanding_flight = ip_flightID;
        if v_people_on_board > 0 then
           leave sp_main; -- Cannot retire if pilots are still assigned, even if plane location is null
        end if;
        -- If plane location is null and no pilots assigned, proceed to delete.

    else
        select count(*) into v_people_on_board
        from person
        where locationID = v_plane_locationID;

        if v_people_on_board > 0 then
            leave sp_main;
        end if;
    end if;


    delete from flight where flightID = ip_flightID;

	-- Ensure that the flight is on the ground
    -- Ensure that the flight does not have any more legs
    
    -- Ensure that there are no more people on the plane supporting the flight
    
    -- Remove the flight from the system

end //
delimiter ;

-- [13] simulation_cycle()
-- -----------------------------------------------------------------------------
/* This stored procedure executes the next step in the simulation cycle.  The flight
with the smallest next time in chronological order must be identified and selected.
If multiple flights have the same time, then flights that are landing should be
preferred over flights that are taking off.  Similarly, flights with the lowest
identifier in alphabetical order should also be preferred.

If an airplane is in flight and waiting to land, then the flight should be allowed
to land, passengers allowed to disembark, and the time advanced by one hour until
the next takeoff to allow for preparations.

If an airplane is on the ground and waiting to takeoff, then the passengers should
be allowed to board, and the time should be advanced to represent when the airplane
will land at its next location based on the leg distance and airplane speed.

If an airplane is on the ground and has reached the end of its route, then the
flight crew should be recycled to allow rest, and the flight itself should be
retired from the system. */
-- -----------------------------------------------------------------------------
drop procedure if exists simulation_cycle;
delimiter //
create procedure simulation_cycle ()
sp_main: begin
    declare selected_flightID varchar(50);
    declare selected_status varchar(100);
    declare current_progress integer;
    declare selected_routeID varchar(50);
    declare max_legs integer;

    -- Identify the next flight to process
    select flightID, airplane_status, progress, routeID
    into selected_flightID, selected_status, current_progress, selected_routeID
    from flight
    where next_time is not null -- Consider only flights with a scheduled next action
    order by next_time asc,
             case when airplane_status = 'in_flight' then 0 else 1 end asc, -- Prioritize landing
             flightID asc -- Alphabetical tie-breaker
    limit 1;

    -- If no flight is found, exit
    if selected_flightID is null then
        leave sp_main;
    end if;

    -- Get the total number of legs for the route
    select max(sequence) into max_legs 
    from route_path 
    where routeID = selected_routeID;
    
    if max_legs is null then 
        set max_legs = 0; 
    end if; -- Handle routes with no paths if necessary

    -- Process based on status
    if selected_status = 'in_flight' then
        -- Flight is landing
        call flight_landing(selected_flightID);
        call passengers_disembark(selected_flightID);

        -- Re-fetch progress after landing as flight_landing might update it
        select progress into current_progress from flight where flightID = selected_flightID;

        -- Check if it has now reached the end *after* landing
        if current_progress >= max_legs then
             call recycle_crew(selected_flightID);
             call retire_flight(selected_flightID);
         end if;
         -- Note: flight_landing is expected to set the next_time for 1 hour later turnaround

    elseif selected_status = 'on_ground' then
        -- Flight is on the ground

        -- Check if it has reached the end of its route
        if current_progress >= max_legs then
            -- Recycle crew and retire flight
            call recycle_crew(selected_flightID);
            call retire_flight(selected_flightID);
        else
            -- Board passengers and takeoff for the next leg
            call passengers_board(selected_flightID);
            call flight_takeoff(selected_flightID);
            -- Note: flight_takeoff updates the next_time to the landing time of the next leg
        end if;
    end if;

	-- Identify the next flight to be processed
    
    -- If the flight is in the air:
		-- Land the flight and disembark passengers
        -- If it has reached the end:
			-- Recycle crew and retire flight
            
	-- If the flight is on the ground:
		-- Board passengers and have the plane takeoff
        
	-- Hint: use the previously created procedures

end //
delimiter ;

-- [14] flights_in_the_air()
-- -----------------------------------------------------------------------------
/* This view describes where flights that are currently airborne are located. 
We need to display what airports these flights are departing from, what airports 
they are arriving at, the number of flights that are flying between the 
departure and arrival airport, the list of those flights (ordered by their 
flight IDs), the earliest and latest arrival times for the destinations and the 
list of planes (by their respective flight IDs) flying these flights. */
-- -----------------------------------------------------------------------------
create or replace view flights_in_the_air (departing_from, arriving_at, num_flights,
	flight_list, earliest_arrival, latest_arrival, airplane_list) as
select
    l.departure as departing_from,
    l.arrival as arriving_at,
    count(distinct f.flightID) as num_flights,
    group_concat(distinct f.flightID order by f.flightID separator ',') as flight_list,
    min(f.next_time) as earliest_arrival,
    max(f.next_time) as latest_arrival,
    group_concat(distinct concat(a.locationID) order by f.flightID separator ',') as airplane_list
from flight f
	join route_path rp on f.routeID = rp.routeID and f.progress = rp.sequence
	join leg l on rp.legID = l.legID
    join airplane a on (f.support_airline = a.airlineID and f.support_tail = a.tail_num)
where f.airplane_status = 'in_flight' and f.progress = rp.sequence
group by l.departure, l.arrival;

-- [15] flights_on_the_ground()
-- ------------------------------------------------------------------------------
/* This view describes where flights that are currently on the ground are 
located. We need to display what airports these flights are departing from, how 
many flights are departing from each airport, the list of flights departing from 
each airport (ordered by their flight IDs), the earliest and latest arrival time 
amongst all of these flights at each airport, and the list of planes (by their 
respective flight IDs) that are departing from each airport.*/
-- ------------------------------------------------------------------------------
create or replace view flights_on_the_ground (departing_from, num_flights, 
	flight_list, earliest_arrival, latest_arrival, airplane_list) as
select
    t.departing_from,
    count(*) AS num_flights,
    group_concat(t.flightID order by t.flightID separator ',') as flight_list,
    min(t.next_time) as earliest_arrival,
    max(t.next_time) as latest_arrival,
    group_concat(t.locationID order by t.flightID separator ',') as airplane_list
from (
    -- Case 1: If flight has a next leg and hasn't reached its destination
    select
        l_next.departure as departing_from,
        f.flightID,
        f.next_time,
        a.locationID
    from flight f
    join (
        select routeID, max(sequence) as max_seq
        from route_path
        group by routeID
    ) as rm on f.routeID = rm.routeID
    join route_path rp_next on f.routeID = rp_next.routeID and rp_next.sequence = f.progress + 1
    join leg l_next on rp_next.legID = l_next.legID
    join airplane a on f.support_airline = a.airlineID and f.support_tail = a.tail_num
    where f.airplane_status = 'on_ground' and f.progress < rm.max_seq

	union

    -- Case 2: If Flight has completed its route, therefore has no legs
    select
        l_last.arrival as departing_from,
        f.flightID,
        f.next_time,
        a.locationID
    from flight f
    join (
        select routeID, max(sequence) as max_seq
        from route_path
        group by routeID
    ) as rm on f.routeID = rm.routeID
    join route_path rp_last on f.routeID = rp_last.routeID and rp_last.sequence = rm.max_seq
    join leg l_last on rp_last.legID = l_last.legID
    join airplane a on f.support_airline = a.airlineID and f.support_tail = a.tail_num
    where f.airplane_status = 'on_ground' and f.progress = rm.max_seq
) t
group by t.departing_from;

-- [16] people_in_the_air()
-- -----------------------------------------------------------------------------
/* This view describes where people who are currently airborne are located. We 
need to display what airports these people are departing from, what airports 
they are arriving at, the list of planes (by the location id) flying these 
people, the list of flights these people are on (by flight ID), the earliest 
and latest arrival times of these people, the number of these people that are 
pilots, the number of these people that are passengers, the total number of 
people on the airplane, and the list of these people by their person id. */
-- -----------------------------------------------------------------------------
create or replace view people_in_the_air (departing_from, arriving_at, num_airplanes,
	airplane_list, flight_list, earliest_arrival, latest_arrival, num_pilots,
	num_passengers, joint_pilots_passengers, person_list) as
select
    l.departure as departing_from,
    l.arrival as arriving_at,
    count(distinct plane.locationID) as num_airplanes,
    group_concat(distinct plane.locationID order by plane.locationID separator ',') as airplane_list,
    group_concat(distinct f.flightID order by f.flightID separator ',') as flight_list,
    min(f.next_time) as earliest_arrival,
    max(f.next_time) as latest_arrival,
    count(distinct case when p.personID in (select personID from pilot) then p.personID else null end) as num_pilots,
    count(distinct case when p.personID in (select personID from passenger) then p.personID else null end) as num_passengers,
    count(distinct p.personID) as joint_pilots_passengers,
    group_concat(distinct p.personID order by p.personID separator ',') as person_list
from person p
join airplane plane on p.locationID = plane.locationID
join flight f on plane.tail_num = f.support_tail
join route_path rp on f.routeID = rp.routeID and f.progress = rp.sequence
join leg l on rp.legID = l.legID
where f.airplane_status = 'in_flight'
group by l.departure, l.arrival;

-- [17] people_on_the_ground()
-- -----------------------------------------------------------------------------
/* This view describes where people who are currently on the ground and in an 
airport are located. We need to display what airports these people are departing 
from by airport id, location id, and airport name, the city and state of these 
airports, the number of these people that are pilots, the number of these people 
that are passengers, the total number people at the airport, and the list of 
these people by their person id. */
-- -----------------------------------------------------------------------------
create or replace view people_on_the_ground (departing_from, airport, airport_name,
	city, state, country, num_pilots, num_passengers, joint_pilots_passengers, person_list) as
select
    ap.airportID as departing_from, -- 'departing_from' represents the current airport location
    ap.locationID as airport,      -- 'airport' represents the locationID of the airport
    ap.airport_name,
    ap.city,
    ap.state,
    ap.country,
    count(distinct case when p.personID in (select personID from pilot) then p.personID else null end) as num_pilots,
    count(distinct case when p.personID in (select personID from passenger) then p.personID else null end) as num_passengers,
    count(distinct p.personID) as joint_pilots_passengers,
    group_concat(distinct p.personID order by p.personID separator ',') as person_list
from person p
join airport ap on p.locationID = ap.locationID
group by ap.airportID, ap.locationID, ap.airport_name, ap.city, ap.state, ap.country;

-- [18] route_summary()
-- -----------------------------------------------------------------------------
/* This view will give a summary of every route. This will include the routeID, 
the number of legs per route, the legs of the route in sequence, the total 
distance of the route, the number of flights on this route, the flightIDs of 
those flights by flight ID, and the sequence of airports visited by the route. */
-- -----------------------------------------------------------------------------
create or replace view route_summary (route, num_legs, leg_sequence, route_length,
	num_flights, flight_list, airport_sequence) as

with RouteLegs as (
    select
        rp.routeID,
        count(rp.legID) as num_legs,
        group_concat(rp.legID order by rp.sequence separator ',') as leg_sequence,
        sum(l.distance) as route_length,
        group_concat(concat(l.departure, '->', l.arrival) 
                     order by rp.sequence                 
                     separator ',')                       
                 as airport_sequence_formatted
    from route_path rp
    join leg l on rp.legID = l.legID
    group by rp.routeID
),
RouteFlights as (
    -- Aggregate flight information for each route
    select
        f.routeID,
        -- Count unique flights assigned to the route
        count(distinct f.flightID) as num_flights,
        -- Comma-separated list of unique flight IDs, ordered alphabetically
        group_concat(distinct f.flightID order by f.flightID separator ',') as flight_list
    from flight f
    group by f.routeID
)
select
    r.routeID as route,
    ifnull(rl.num_legs, 0) as num_legs,
    rl.leg_sequence, -- Will be NULL if no legs
    rl.route_length, -- Will be NULL if no legs
    -- Use IFNULL to show 0 if a route has no flights assigned
    ifnull(rf.num_flights, 0) as num_flights,
    rf.flight_list, 
    rl.airport_sequence_formatted as airport_sequence 
from route r
left join RouteLegs rl on r.routeID = rl.routeID
left join RouteFlights rf on r.routeID = rf.routeID;


-- [19] alternative_airports()
-- -----------------------------------------------------------------------------
/* This view displays airports that share the same city and state. It should 
specify the city, state, the number of airports shared, and the lists of the 
airport codes and airport names that are shared both by airport ID. */
-- -----------------------------------------------------------------------------
create or replace view alternative_airports (city, state, country, num_airports,
	airport_code_list, airport_name_list) as
select
    city,
    state,
    country,
    count(*) as num_airports,
    group_concat(airportID order by airportID separator ',') as airport_code_list,
    group_concat(airport_name order by airportID separator ', ') as airport_name_list
from airport
group by city, state, country
having count(*) > 1;
