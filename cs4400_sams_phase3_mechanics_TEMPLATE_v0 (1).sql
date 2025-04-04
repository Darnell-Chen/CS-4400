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
drop procedure if exists add_airplane;
delimiter //
create procedure add_airplane (in ip_airlineID varchar(50), in ip_tail_num varchar(50),
	in ip_seat_capacity integer, in ip_speed integer, in ip_locationID varchar(50),
    in ip_plane_type varchar(100), in ip_maintenanced boolean, in ip_model varchar(50),
    in ip_neo boolean)
sp_main: begin
	if not exists( select 1 from airline where airlineID=ip_airlineID) then
		leave sp_main;
	end if; 
    if exists (select 1 from airplane where airlineID = ip_airlineID and tail_num = ip_tail_num) then
        leave sp_main; 
    end if;

    if ip_seat_capacity is null or ip_seat_capacity <= 0 then
        leave sp_main; 
    end if;
    if ip_speed is null or ip_speed <= 0 then
        leave sp_main; 
    end if;

    if ip_locationID is null then
        leave sp_main;
    end if;
    if exists (select 1 from location where locationID = ip_locationID) then
        leave sp_main; 
    end if;

    if ip_plane_type = 'Boeing' then
        if ip_neo is not null then
            leave sp_main;
        end if;
    elseif ip_plane_type = 'Airbus' then
        if ip_model is not null then
            leave sp_main; 
        end if;
        if ip_maintenanced is not null then
             leave sp_main; 
        end if;
    elseif ip_plane_type is not null then
         if ip_model is not null or ip_neo is not null or ip_maintenanced is not null then
              leave sp_main;
         end if;
    else 
         if ip_model is not null or ip_neo is not null or ip_maintenanced is not null then
              leave sp_main;
         end if;
    end if;

    insert into location (locationID) values (ip_locationID);

    insert into airplane (airlineID, tail_num, seat_capacity, speed, locationID, plane_type, maintenanced, model, neo)
    values (ip_airlineID, ip_tail_num, ip_seat_capacity, ip_speed, ip_locationID, ip_plane_type, ip_maintenanced, ip_model, ip_neo);

    


	-- Ensure that the plane type is valid: Boeing, Airbus, or neither
    -- Ensure that the type-specific attributes are accurate for the type
    -- Ensure that the airplane and location values are new and unique
    -- Add airplane and location into respective tables

end //
delimiter ;

-- [2] add_airport()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new airport.  A new airport must have a unique
identifier along with a new and database-wide unique location if it will be used
to support airplane takeoffs and landings.  An airport may have a longer, more
descriptive name.  An airport must also have a city, state, and country designation. */
-- -----------------------------------------------------------------------------
drop procedure if exists add_airport;
delimiter //
create procedure add_airport (in ip_airportID char(3), in ip_airport_name varchar(200),
    in ip_city varchar(100), in ip_state varchar(100), in ip_country char(3), in ip_locationID varchar(50))
sp_main: begin
if exists (select 1 from airport where airportID = ip_airportID) then
        leave sp_main; 
    end if;

    if ip_city is null or ip_state is null or ip_country is null then
        leave sp_main; 
    end if;

    if ip_locationID is not null then
        if exists (select 1 from location where locationID = ip_locationID) then
            leave sp_main; 
        end if;

        insert into location (locationID) values (ip_locationID);
    end if;

   
    insert into airport (airportID, airport_name, city, state, country, locationID)
    values (ip_airportID, ip_airport_name, ip_city, ip_state, ip_country, ip_locationID);

	-- Ensure that the airport and location values are new and unique
    -- Add airport and location into respective tables

end //
delimiter ;

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
drop procedure if exists add_person;
delimiter //
create procedure add_person (in ip_personID varchar(50), in ip_first_name varchar(100),
    in ip_last_name varchar(100), in ip_locationID varchar(50), in ip_taxID varchar(50),
    in ip_experience integer, in ip_miles integer, in ip_funds integer)
sp_main: begin
    if ip_personID is null or ip_first_name is null or ip_locationID is null then
        -- Essential information missing
        leave sp_main;
    end if;

    -- Uniqueness Check: Ensure the personID doesn't already exist
    if exists (select 1 from person where personID = ip_personID) then
        -- Person ID must be unique
        leave sp_main;
    end if;

    -- Location Check: Ensure the provided locationID exists in the location table
    if not exists (select 1 from location where locationID = ip_locationID) then
        -- The specified location must already exist in the database
        leave sp_main;
    end if;

    -- Role Validation: Determine if pilot or passenger and ensure exclusivity and completeness
    -- Case 1: Potentially a Pilot (taxID and experience provided)
    if (ip_taxID is not null and ip_experience is not null) then
        -- Check if passenger info was also provided (violates exclusivity)
        if (ip_miles is not null or ip_funds is not null) then
            -- Cannot be both a pilot and have passenger attributes
            leave sp_main;
        end if;

        -- Valid Pilot: Insert into person, then pilot
        insert into person (personID, first_name, last_name, locationID)
        values (ip_personID, ip_first_name, ip_last_name, ip_locationID);

        insert into pilot (personID, taxID, experience, commanding_flight) -- Assuming new pilots aren't immediately commanding a flight
        values (ip_personID, ip_taxID, ip_experience, NULL);

    -- Case 2: Potentially a Passenger (miles and funds provided)
    elseif (ip_miles is not null and ip_funds is not null) then
        -- Check if pilot info was also provided (violates exclusivity)
        if (ip_taxID is not null or ip_experience is not null) then
            -- Cannot be both a passenger and have pilot attributes
            leave sp_main;
        end if;

        -- Valid Passenger: Insert into person, then passenger
        insert into person (personID, first_name, last_name, locationID)
        values (ip_personID, ip_first_name, ip_last_name, ip_locationID);

        insert into passenger (personID, miles, funds)
        values (ip_personID, ip_miles, ip_funds);

    -- Case 3: Invalid Role Definition
    else
        -- Neither a complete pilot definition nor a complete passenger definition provided
        leave sp_main;
    end if;

	-- Ensure that the location is valid
    -- Ensure that the persion ID is unique
    -- Ensure that the person is a pilot or passenger
    -- Add them to the person table as well as the table of their respective role

end //
delimiter ;

-- [4] grant_or_revoke_pilot_license()
-- -----------------------------------------------------------------------------
/* This stored procedure inverts the status of a pilot license.  If the license
doesn't exist, it must be created; and, if it aready exists, then it must be removed. */
-- -----------------------------------------------------------------------------
drop procedure if exists grant_or_revoke_pilot_license;
delimiter //
create procedure grant_or_revoke_pilot_license (in ip_personID varchar(50), in ip_license varchar(100))
sp_main: begin
declare v_license_exists int default 0;

    if not exists (select 1 from pilot where personID = ip_personID) then
        leave sp_main;
    end if;

    select count(*) into v_license_exists
    from pilot_licenses
    where personID = ip_personID and license = ip_license;

    if v_license_exists > 0 then
        delete from pilot_licenses
        where personID = ip_personID and license = ip_license;
    else
        insert into pilot_licenses (personID, license)
        values (ip_personID, ip_license);
    end if;


	-- Ensure that the person is a valid pilot
    -- If license exists, delete it, otherwise add the license

end //
delimiter ;

-- [5] offer_flight()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new flight.  The flight can be defined before
an airplane has been assigned for support, but it must have a valid route.  And
the airplane, if designated, must not be in use by another flight.  The flight
can be started at any valid location along the route except for the final stop,
and it will begin on the ground.  You must also include when the flight will
takeoff along with its cost. */
-- -----------------------------------------------------------------------------
drop procedure if exists offer_flight;
delimiter //
create procedure offer_flight (in ip_flightID varchar(50), in ip_routeID varchar(50),
    in ip_support_airline varchar(50), in ip_support_tail varchar(50), in ip_progress integer,
    in ip_next_time time, in ip_cost integer)
sp_main: begin
declare v_route_exists int default 0;
    declare v_plane_exists int default 0;
    declare v_plane_assigned int default 0;
    declare v_max_legs int default 0;

    if exists (select 1 from flight where flightID = ip_flightID) then
        leave sp_main;
    end if;

    select count(*) into v_route_exists from route where routeID = ip_routeID;
    if v_route_exists = 0 then
        leave sp_main;
    end if;

    if ip_support_airline is not null and ip_support_tail is not null then
        select count(*) into v_plane_exists from airplane
        where airlineID = ip_support_airline and tail_num = ip_support_tail;
        if v_plane_exists = 0 then
            leave sp_main;
        end if;

        select count(*) into v_plane_assigned from flight
        where support_airline = ip_support_airline and support_tail = ip_support_tail;
        if v_plane_assigned > 0 then
            leave sp_main;
        end if;
    elseif ip_support_airline is not null or ip_support_tail is not null then
         leave sp_main;
    end if;

    select count(*) into v_max_legs from route_path where routeID = ip_routeID;
    if ip_progress is null or ip_progress < 0 or ip_progress >= v_max_legs then
       leave sp_main;
    end if;

    if ip_cost is null or ip_cost < 0 then
       leave sp_main;
    end if;

    if ip_next_time is null then
        leave sp_main;
    end if;


    insert into flight (flightID, routeID, support_airline, support_tail, progress, airplane_status, next_time, cost)
    values (ip_flightID, ip_routeID, ip_support_airline, ip_support_tail, ip_progress, 'on_ground', ip_next_time, ip_cost);

	-- Ensure that the airplane exists
    -- Ensure that the route exists
    -- Ensure that the progress is less than the length of the route
    -- Create the flight with the airplane starting in on the ground

end //
delimiter ;

-- [6] flight_landing()
-- -----------------------------------------------------------------------------
/* This stored procedure updates the state for a flight landing at the next airport
along it's route.  The time for the flight should be moved one hour into the future
to allow for the flight to be checked, refueled, restocked, etc. for the next leg
of travel.  Also, the pilots of the flight should receive increased experience, and
the passengers should have their frequent flyer miles updated. */
-- -----------------------------------------------------------------------------
drop procedure if exists flight_landing;
delimiter //
create procedure flight_landing (in ip_flightID varchar(50))
sp_main: begin
declare v_routeID varchar(50);
    declare v_progress integer;
    declare v_airplane_status varchar(100);
    declare v_support_airline varchar(50);
    declare v_support_tail varchar(50);
    declare v_plane_intrinsic_loc varchar(50);
    declare v_legID varchar(50);
    declare v_distance integer;
    declare v_arrival_airport char(3);
    declare v_arrival_loc varchar(50);
    declare v_current_next_time time;

    select routeID, progress, airplane_status, support_airline, support_tail, next_time
    into v_routeID, v_progress, v_airplane_status, v_support_airline, v_support_tail, v_current_next_time
    from flight where flightID = ip_flightID;

    if v_routeID is null then
        leave sp_main; 
    end if;

    if v_airplane_status <> 'in_flight' then
        leave sp_main;
    end if;

    if v_support_airline is null or v_support_tail is null then
         leave sp_main;
    end if;

    select locationID into v_plane_intrinsic_loc
    from airplane where airlineID = v_support_airline and tail_num = v_support_tail;
    if v_plane_intrinsic_loc is null then leave sp_main; end if; 

    select legID into v_legID
    from route_path where routeID = v_routeID and sequence = v_progress;

    if v_legID is null then
        leave sp_main; 
    end if;

    select distance, arrival into v_distance, v_arrival_airport
    from leg where legID = v_legID;
    if v_arrival_airport is null then leave sp_main; end if; 

    select locationID into v_arrival_loc from airport where airportID = v_arrival_airport;
    if v_arrival_loc is null then
        leave sp_main; 
    end if;

    update pilot
    set experience = experience + 1
    where commanding_flight = ip_flightID;

    update passenger pas
    join person per on pas.personID = per.personID
    set pas.miles = pas.miles + v_distance
    where per.locationID = v_plane_intrinsic_loc; 
    update flight
    set airplane_status = 'on_ground',
        next_time = addtime(v_current_next_time, '01:00:00')
    where flightID = ip_flightID;

    update airplane
    set locationID = v_arrival_loc
    where airlineID = v_support_airline and tail_num = v_support_tail;

    update person
    set locationID = v_arrival_loc
    where locationID = v_plane_intrinsic_loc;

	-- Ensure that the flight exists
    -- Ensure that the flight is in the air
    
    -- Increment the pilot's experience by 1
    -- Increment the frequent flyer miles of all passengers on the plane
    -- Update the status of the flight and increment the next time to 1 hour later
		-- Hint: use addtime()

end //
delimiter ;

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
    DECLARE v_tail VARCHAR(50);
    DECLARE v_airline VARCHAR(50);
    DECLARE v_progress INT;
    DECLARE v_status VARCHAR(50);
    DECLARE v_model VARCHAR(50);
    DECLARE v_speed INT;
    DECLARE v_route VARCHAR(50);
    DECLARE v_total_legs INT;
    DECLARE v_legID VARCHAR(50);
    DECLARE v_distance INT;
    DECLARE v_pilot_count INT;
    DECLARE v_flight_seconds INT;
    
    -- Check if flight exists and get relevant info
    SELECT support_airline, support_tail, progress, airplane_status, routeID, next_time
    INTO v_airline, v_tail, v_progress, v_status, v_route, @departure_time
    FROM flight
    WHERE flightID = ip_flightID;

    -- Proceed only if status is 'on_ground'
    IF v_status <> 'on_ground' THEN
        LEAVE sp_main;
    END IF;

    -- Check how many total legs are on this route
    SELECT COUNT(*) INTO v_total_legs
    FROM route_path
    WHERE routeID = v_route;

    -- If the flight has no more legs, exit
    IF v_progress >= v_total_legs THEN
        LEAVE sp_main;
    END IF;

    -- Get airplane model and speed
    SELECT model, speed
    INTO v_model, v_speed
    FROM airplane
    WHERE airlineID = v_airline AND tail_num = v_tail;

    -- Count assigned pilots
    SELECT COUNT(*) INTO v_pilot_count
    FROM pilot
    WHERE commanding_flight = ip_flightID;

    -- Check pilot requirement
    IF (v_model LIKE 'Boeing%' AND v_pilot_count < 2) OR
       (v_model NOT LIKE 'Boeing%' AND v_pilot_count < 1) THEN
        -- Not enough pilots: delay the flight by 30 minutes
        UPDATE flight
        SET next_time = ADDTIME(next_time, '00:30:00')
        WHERE flightID = ip_flightID;
        LEAVE sp_main;
    END IF;

    -- Get next leg ID
    SELECT legID INTO v_legID
    FROM route_path
    WHERE routeID = v_route AND sequence = v_progress + 1;

    -- Get distance of the next leg
    SELECT distance INTO v_distance
    FROM leg
    WHERE legID = v_legID;

    -- Calculate flight time in seconds (more precise)
    SET v_flight_seconds = (v_distance * 3600) DIV v_speed; 
    
    -- Update flight status and arrival time
    UPDATE flight
    SET progress = progress + 1,
        airplane_status = 'in_flight',
        next_time = ADDTIME(@departure_time, SEC_TO_TIME(v_flight_seconds))
    WHERE flightID = ip_flightID;
END //
DELIMITER;

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
      AND p.funds >= v_flight_cost
      AND pe.locationID NOT LIKE 'plane_%';
    
    -- SECTION 4: Board passengers if conditions met
    IF v_available_seats > 0 AND v_passengers_to_board_count > 0 THEN
        -- Insert eligible passengers into temp table ordered by funds
        INSERT INTO temp_passengers_to_board
        SELECT p.personID, p.funds
        FROM passenger p
        JOIN person pe ON p.personID = pe.personID
        JOIN passenger_vacations pv ON p.personID = pv.personID
        WHERE pe.locationID = v_boarding_location
          AND pv.airportID = v_flight_arrival
          AND p.funds >= v_flight_cost
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

    -- Step 3: Get airplane’s current location
    SELECT a.locationID INTO v_airplane_location
    FROM airplane a
    WHERE a.airlineID = v_support_airline AND a.tail_num = v_support_tail;

    -- Step 4: Get airport’s locationID
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
    declare routeID varchar(50);
    declare max_legs integer;

    -- Identify the next flight to process
    select flightID, airplane_status, progress, routeID
    into selected_flightID, selected_status, current_progress, routeID
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
    select max(sequence) into max_legs from route_path where routeID = routeID;
    if max_legs is null then set max_legs = 0; end if; -- Handle routes with no paths if necessary

    -- Process based on status
    if selected_status = 'in_flight' then
        -- Flight is landing
        call flight_landing(selected_flightID);
        call passengers_disembark(selected_flightID);

        -- Re-fetch progress after landing as flight_landing might update it (though it shouldn't based on its description)
        -- We need to check if it *just* completed its final leg *after* landing.
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
    count(f.flightID) as num_flights,
    group_concat(f.flightID order by f.flightID separator ',') as flight_list,
    min(f.next_time) as earliest_arrival,
    max(f.next_time) as latest_arrival,
    group_concat(f.support_tail order by f.flightID separator ',') as airplane_list
from flight f
join route_path rp on f.routeID = rp.routeID and f.progress = rp.sequence
join leg l on rp.legID = l.legID
where f.airplane_status = 'in_flight'
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
    ap.airportID as departing_from,
    count(f.flightID) as num_flights,
    group_concat(f.flightID order by f.flightID separator ',') as flight_list,
    min(f.next_time) as earliest_departure, -- Represents earliest next action time (takeoff)
    max(f.next_time) as latest_departure,  -- Represents latest next action time (takeoff)
    group_concat(f.support_tail order by f.flightID separator ',') as airplane_list
from flight f
join airplane plane on f.support_tail = plane.tail_num
join airport ap on plane.locationID = ap.locationID -- Find the airport where the plane is
left join (select routeID, max(sequence) as max_seq from route_path group by routeID) rm
          on f.routeID = rm.routeID -- Get max sequence for the route
where f.airplane_status = 'on_ground'
  and f.progress < ifnull(rm.max_seq, 0) -- Only include flights that have not completed their route
group by ap.airportID;

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
    -- Aggregate leg information for each route
    select
        rp.routeID,
        count(rp.legID) as num_legs,
        -- Comma-separated list of leg IDs, ordered by their sequence in the route
        group_concat(rp.legID order by rp.sequence separator ',') as leg_sequence,
        -- Sum of distances of all legs in the route
        sum(l.distance) as route_length,
        -- Get the departure airport of the very first leg (sequence = 1)
        group_concat(
            case
                when rp.sequence = 1 then l.departure
                else null
            end order by rp.sequence separator '' -- Effectively picks the single departure
        ) as first_departure,
        -- Get the sequence of arrival airports, ordered by leg sequence
        group_concat(l.arrival order by rp.sequence separator '->') as arrival_sequence
    from route_path rp
    join leg l on rp.legID = l.legID
    group by rp.routeID
),
RouteFlights as (
    -- Aggregate flight information for each route
    select
        f.routeID,
        -- Count distinct flights assigned to the route
        count(distinct f.flightID) as num_flights,
        -- Comma-separated list of distinct flight IDs, ordered alphabetically
        group_concat(distinct f.flightID order by f.flightID separator ',') as flight_list
    from flight f -- Alias added for clarity
    group by f.routeID
)
-- Combine Route, RouteLegs, and RouteFlights information
select
    r.routeID as route,
    -- Use IFNULL in case a route has no legs defined in route_path
    ifnull(rl.num_legs, 0) as num_legs,
    rl.leg_sequence, -- Will be NULL if no legs
    rl.route_length, -- Will be NULL if no legs
    -- Use IFNULL in case a route has no flights assigned
    ifnull(rf.num_flights, 0) as num_flights,
    rf.flight_list, -- Will be NULL if no flights
    -- Construct the full airport sequence: First Departure -> Arrival 1 -> Arrival 2 -> ...
    -- If rl.first_departure is NULL (no legs), the result of CONCAT is NULL, which is correct.
    concat(rl.first_departure, '->', rl.arrival_sequence) as airport_sequence
from route r
-- Left join to include routes even if they have no legs or no flights
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
