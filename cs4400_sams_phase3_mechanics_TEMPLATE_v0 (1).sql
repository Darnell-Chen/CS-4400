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
drop procedure if exists flight_takeoff;
delimiter //
create procedure flight_takeoff (in ip_flightID varchar(50))
sp_main: begin
	    declare v_airplane_status varchar(100);
    declare v_current_progress integer;
    declare v_routeID varchar(50);
    declare v_support_tail varchar(50);
    declare v_next_legID varchar(50);
    declare v_max_legs integer;
    declare v_distance integer;
    declare v_speed integer;
    declare v_plane_type varchar(100);
    declare v_pilot_count integer;
    declare v_min_pilots integer;
    declare v_flight_time_minutes integer;
    declare v_plane_locationID varchar(50);
    declare v_current_next_time time;
    declare v_airport_locationID varchar(50);

    -- Ensure that the flight exists
    select airplane_status, progress, routeID, support_tail, next_time
    into v_airplane_status, v_current_progress, v_routeID, v_support_tail, v_current_next_time
    from flight
    where flightID = ip_flightID;

    if v_routeID is null then
        leave sp_main; -- Flight doesn't exist
    end if;

    -- Ensure that the flight is on the ground
    if v_airplane_status <> 'on_ground' then
        leave sp_main;
    end if;

    -- Get airplane details (including its current location)
    select plane_type, speed, locationID into v_plane_type, v_speed, v_plane_locationID
    from airplane
    where tail_num = v_support_tail;

    -- Verify the plane is at a known airport location
    select locationID into v_airport_locationID
    from airport
    where locationID = v_plane_locationID;

    if v_airport_locationID is null then
       leave sp_main; -- Plane not at a recognized airport
    end if;

    -- Ensure that the flight has another leg to fly
    select max(sequence) into v_max_legs from route_path where routeID = v_routeID;
    if v_max_legs is null or v_current_progress >= v_max_legs then
        leave sp_main; -- No more legs or route path issue
    end if;

    -- Get the next leg details
    select legID into v_next_legID
    from route_path
    where routeID = v_routeID and sequence = v_current_progress + 1;

    if v_next_legID is null then
        leave sp_main; -- Should not happen if previous check passed, but safe check
    end if;

    -- Check airplane speed
    if v_speed is null or v_speed <= 0 then -- Cannot fly without positive speed
        leave sp_main;
    end if;

    -- Ensure that there are enough pilots (1 for Airbus and general, 2 for Boeing)
    select count(*) into v_pilot_count
    from pilot
    where commanding_flight = ip_flightID;

    if v_plane_type = 'Boeing' then
        set v_min_pilots = 2;
    else
        set v_min_pilots = 1; -- For Airbus, general, or null/unknown plane_type
    end if;

    -- If there are not enough pilots, move next time to 30 minutes later
    if v_pilot_count < v_min_pilots then
        update flight
        set next_time = addtime(v_current_next_time, '00:30:00')
        where flightID = ip_flightID;
        leave sp_main;
    end if;

    -- Calculate the flight time using the speed of airplane and distance of leg
    select distance into v_distance
    from leg
    where legID = v_next_legID;

    set v_flight_time_minutes = CEILING((cast(v_distance as double) / v_speed) * 60);

    -- Increment the progress and set the status to in flight
    -- Update the next time using the calculated flight time (added to current time)
    update flight
    set progress = v_current_progress + 1,
        airplane_status = 'in_flight',
		next_time = addtime(v_current_next_time, SEC_TO_TIME(v_flight_time_minutes * 60)) -- Landing time
    where flightID = ip_flightID;

    -- Ensure pilots assigned to the flight share the plane's location ID.
    -- Passengers should have been moved by passengers_board().
    update person p join pilot pil on p.personID = pil.personID
    set p.locationID = v_plane_locationID
    where pil.commanding_flight = ip_flightID;



	-- Ensure that the flight exists
    -- Ensure that the flight is on the ground
    -- Ensure that the flight has another leg to fly
    -- Ensure that there are enough pilots (1 for Airbus and general, 2 for Boeing)
		-- If there are not enough, move next time to 30 minutes later
        
	-- Increment the progress and set the status to in flight
    -- Calculate the flight time using the speed of airplane and distance of leg
    -- Update the next time using the flight time

end //
delimiter ;

-- [8] passengers_board()
-- -----------------------------------------------------------------------------
/* This stored procedure updates the state for passengers getting on a flight at
its current airport.  The passengers must be at the same airport as the flight,
and the flight must be heading towards that passenger's desired destination.
Also, each passenger must have enough funds to cover the flight.  Finally, there
must be enough seats to accommodate all boarding passengers. */
-- -----------------------------------------------------------------------------
drop procedure if exists passengers_board;
delimiter //
create procedure passengers_board (in ip_flightID varchar(50))
sp_main: begin
	declare v_flight_exists int;
    declare v_airplane_status varchar(100);
    declare v_routeID varchar(50);
    declare v_current_progress integer;
    declare v_max_legs integer;
    declare v_support_tail varchar(50);
    declare v_plane_locationID varchar(50);
    declare v_current_airportID varchar(50);
    declare v_next_legID varchar(50);
    declare v_next_arrival_airportID varchar(50);
    declare v_flight_cost decimal(10, 2); -- Assuming cost is decimal
    declare v_seat_capacity integer;
    declare v_passengers_on_plane integer;
    declare v_available_seats integer;
    declare v_boarding_passengers_count integer;

    -- Temp table to store eligible passengers
    drop temporary table if exists temp_boarding_passengers;
    create temporary table temp_boarding_passengers (
        personID varchar(50) primary key,
        funds decimal(10, 2)
    );

    -- === Initial Flight Checks ===

    -- Ensure the flight exists and get basic details
    select count(*), airplane_status, routeID, progress, support_tail, cost
    into v_flight_exists, v_airplane_status, v_routeID, v_current_progress, v_support_tail, v_flight_cost
    from flight
    where flightID = ip_flightID;

    if v_flight_exists = 0 then
        -- Flight does not exist
        leave sp_main;
    end if;

    -- Ensure that the flight is on the ground
    if v_airplane_status <> 'on_ground' then
        -- Flight is not on the ground
        leave sp_main;
    end if;

    -- Ensure that the flight has another leg to fly
    select max(sequence) into v_max_legs from route_path where routeID = v_routeID;
    if v_max_legs is null or v_current_progress >= v_max_legs then
        -- Flight has completed its route or route is invalid
        leave sp_main;
    end if;

    -- === Gather Flight Location and Next Destination ===

    -- Get airplane details (location, capacity)
    select ap.locationID, ap.seat_capacity
    into v_plane_locationID, v_seat_capacity
    from airplane ap
    where ap.tail_num = v_support_tail;

    if v_plane_locationID is null then
         -- Airplane associated with flight not found (data integrity issue)
        leave sp_main;
    end if;

    -- Get the current airport ID based on the plane's location
    select apt.airportID
    into v_current_airportID
    from airport apt
    where apt.locationID = v_plane_locationID;

    if v_current_airportID is null then
        -- Airplane is not at a recognized airport location
        leave sp_main;
    end if;

    -- Get the next leg ID and its arrival airport
    select rp.legID, l.arrival
    into v_next_legID, v_next_arrival_airportID
    from route_path rp
    join leg l on rp.legID = l.legID
    where rp.routeID = v_routeID and rp.sequence = v_current_progress + 1;

    if v_next_legID is null then
        -- Could not determine the next leg (data integrity issue)
        leave sp_main;
    end if;

    -- === Identify Eligible Passengers ===

    -- Find passengers at the current airport, who want to go to the flight's next destination,
    -- and can afford the flight. We assume the passenger's "next" destination is the one
    -- with the lowest sequence number in their passenger_vacations list.
    insert into temp_boarding_passengers (personID, funds)
    select p.personID, p.funds
    from passenger p
    join person per on p.personID = per.personID
    join (
        -- Subquery to find the lowest sequence vacation destination for each passenger
        select pv.personID, pv.airportID, pv.sequence
        from passenger_vacations pv
        join (
            select personID, min(sequence) as min_seq
            from passenger_vacations
            group by personID
        ) pv_min on pv.personID = pv_min.personID and pv.sequence = pv_min.min_seq
    ) as next_vacation on p.personID = next_vacation.personID
    where
        per.locationID = v_plane_locationID                     -- Passenger is at the plane's location
        and next_vacation.airportID = v_next_arrival_airportID  -- Passenger's next destination matches flight's arrival
        and p.funds >= v_flight_cost;                           -- Passenger can afford the flight

    -- Get the count of passengers attempting to board
    select count(*) into v_boarding_passengers_count from temp_boarding_passengers;

    if v_boarding_passengers_count = 0 then
        -- No eligible passengers trying to board
        drop temporary table if exists temp_boarding_passengers;
        leave sp_main;
    end if;

    -- === Check Seat Capacity ===

    -- Count passengers already on the plane (their location matches the plane's location)
    select count(*)
    into v_passengers_on_plane
    from person per
    join passenger pas on per.personID = pas.personID -- Ensure it's a passenger
    where per.locationID = v_plane_locationID;

    -- Calculate available seats
    set v_available_seats = v_seat_capacity - v_passengers_on_plane;

    -- Check if there are enough seats
    if v_available_seats < v_boarding_passengers_count then
        -- Not enough seats for everyone trying to board
        drop temporary table if exists temp_boarding_passengers;
        leave sp_main; -- Do not board anyone if not all can board
    end if;

    -- === Board Passengers ===

    -- If enough seats, update location and deduct funds for boarding passengers
    -- Update person location to the plane's location
    update person per
    join temp_boarding_passengers tbp on per.personID = tbp.personID
    set per.locationID = v_plane_locationID; -- Move them to the plane

    -- Deduct funds from passenger
    update passenger p
    join temp_boarding_passengers tbp on p.personID = tbp.personID
    set p.funds = p.funds - v_flight_cost;

    -- Clean up temporary table
    drop temporary table if exists temp_boarding_passengers;

	-- Ensure the flight exists
    -- Ensure that the flight is on the ground
    -- Ensure that the flight has further legs to be flown
    
    -- Determine the number of passengers attempting to board the flight
    -- Use the following to check:
		-- The airport the airplane is currently located at
        -- The passengers are located at that airport
        -- The passenger's immediate next destination matches that of the flight
        -- The passenger has enough funds to afford the flight
        
	-- Check if there enough seats for all the passengers
		-- If not, do not add board any passengers
        -- If there are, board them and deduct their funds

end //
delimiter ;

-- [9] passengers_disembark()
-- -----------------------------------------------------------------------------
/* This stored procedure updates the state for passengers getting off of a flight
at its current airport.  The passengers must be on that flight, and the flight must
be located at the destination airport as referenced by the ticket. */
-- -----------------------------------------------------------------------------
drop procedure if exists passengers_disembark;
delimiter //
create procedure passengers_disembark (in ip_flightID varchar(50))
sp_main: begin
  -- Declare variables
    declare v_flight_exists int;
    declare v_airplane_status varchar(100);
    declare v_support_tail varchar(50);
    declare v_plane_locationID varchar(50);
    declare v_current_airportID varchar(50);

    -- Temp table to store passengers who should disembark
    drop temporary table if exists temp_disembarking_passengers;
    create temporary table temp_disembarking_passengers (
        personID varchar(50) primary key,
        vacation_sequence int -- Store the sequence number of the vacation step being completed
    );

    -- === Initial Flight Checks ===

    -- Ensure the flight exists and get its status and plane tail number
    select count(*), airplane_status, support_tail
    into v_flight_exists, v_airplane_status, v_support_tail
    from flight
    where flightID = ip_flightID;

    if v_flight_exists = 0 then
        -- Flight does not exist
        leave sp_main;
    end if;

    -- Ensure that the flight is on the ground (passengers can only disembark when landed)
    -- The prompt description says "Ensure that the flight is in the air" which contradicts
    -- the goal of disembarking AT an airport. Assuming 'on_ground' is the correct prerequisite.
    if v_airplane_status <> 'on_ground' then
        -- Flight is not on the ground
        leave sp_main;
    end if;

    -- === Gather Location Information ===

    -- Get the plane's current location ID
    select locationID
    into v_plane_locationID
    from airplane
    where tail_num = v_support_tail;

    if v_plane_locationID is null then
        -- Airplane not found (data integrity issue)
        leave sp_main;
    end if;

    -- Get the airport ID corresponding to the plane's current location
    select airportID
    into v_current_airportID
    from airport
    where locationID = v_plane_locationID;

    if v_current_airportID is null then
        -- Plane is not at a recognized airport location
        leave sp_main;
    end if;

    -- === Identify Passengers to Disembark ===

    -- Find passengers currently located on the plane whose *immediate next*
    -- vacation destination matches the current airport ID.
    insert into temp_disembarking_passengers (personID, vacation_sequence)
    select
        p.personID,
        next_vacation.sequence
    from
        person p
    join passenger pass on p.personID = pass.personID -- Make sure it's a passenger
    join (
        -- Subquery to find the lowest sequence vacation destination for each person
        select pv.personID, pv.airportID, pv.sequence
        from passenger_vacations pv
        join (
             -- Find the minimum sequence number for each person who has remaining vacations
            select personID, min(sequence) as min_seq
            from passenger_vacations
            group by personID
        ) pv_min on pv.personID = pv_min.personID and pv.sequence = pv_min.min_seq
    ) as next_vacation on p.personID = next_vacation.personID
    where
        p.locationID = v_plane_locationID               -- Passenger is on the plane
        and next_vacation.airportID = v_current_airportID; -- This airport is their immediate next destination

    -- === Update Disembarking Passengers ===

    -- Check if any passengers were found to disembark
    if (select count(*) from temp_disembarking_passengers) > 0 then

        -- Move the appropriate passengers to the airport location
        -- (Their location remains the same ID, as the plane IS at the airport location)
        -- This update isn't strictly necessary if the locationID already matches,
        -- but confirms their status as being AT the airport, not just 'on the plane at the airport'.
        -- No actual change needed to person.locationID as they are already at v_plane_locationID.

        -- Update (remove) the completed vacation plan step for the passengers
        delete pv
        from passenger_vacations pv
        join temp_disembarking_passengers tdp on pv.personID = tdp.personID and pv.sequence = tdp.vacation_sequence;

    end if;

    -- Clean up temporary table
    drop temporary table if exists temp_disembarking_passengers;

	-- Ensure the flight exists
    -- Ensure that the flight is in the air
    
    -- Determine the list of passengers who are disembarking
	-- Use the following to check:
		-- Passengers must be on the plane supporting the flight
        -- Passenger has reached their immediate next destionation airport
        
	-- Move the appropriate passengers to the airport
    -- Update the vacation plans of the passengers

end //
delimiter ;

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
create procedure assign_pilot (in ip_flightID varchar(50), ip_personID varchar(50))
sp_main: begin
declare v_airplane_status varchar(100);
    declare v_current_progress integer;
    declare v_routeID varchar(50);
    declare v_support_tail varchar(50);
    declare v_max_legs integer;
    declare v_pilot_current_flight varchar(50);
    declare v_plane_type varchar(100);
    declare v_plane_locationID varchar(50);
    declare v_pilot_locationID varchar(50);
    declare v_airport_locationID varchar(50);
    declare v_has_license integer;

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
    if v_current_progress >= v_max_legs then
        leave sp_main;
    end if;

    select commanding_flight into v_pilot_current_flight
    from pilot
    where personID = ip_personID;

    if v_pilot_current_flight is not null then
        leave sp_main;
    end if;

    select plane_type, locationID into v_plane_type, v_plane_locationID
    from airplane
    where tail_num = v_support_tail;

    if v_plane_locationID is null then -- Plane needs a location
        leave sp_main;
    end if;

    select locationID into v_airport_locationID
    from airport
    where locationID = v_plane_locationID;

    if v_airport_locationID is null then -- Plane must be at an airport
       leave sp_main;
    end if;

    select locationID into v_pilot_locationID
    from person
    where personID = ip_personID;

    if v_pilot_locationID <> v_airport_locationID then
        leave sp_main;
    end if;

    select count(*) into v_has_license
    from pilot_licenses
    where personID = ip_personID and (license = v_plane_type or license = 'general');

    if v_has_license = 0 then
        leave sp_main;
    end if;

    update pilot
    set commanding_flight = ip_flightID
    where personID = ip_personID;

    update person
    set locationID = v_plane_locationID
    where personID = ip_personID;


	-- Ensure the flight exists
    -- Ensure that the flight is on the ground
    -- Ensure that the flight has further legs to be flown
    
    -- Ensure that the pilot exists and is not already assigned
	-- Ensure that the pilot has the appropriate license
    -- Ensure the pilot is located at the airport of the plane that is supporting the flight
    
    -- Assign the pilot to the flight and update their location to be on the plane

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
declare v_airplane_status varchar(100);
    declare v_current_progress integer;
    declare v_routeID varchar(50);
    declare v_support_tail varchar(50);
    declare v_max_legs integer;
    declare v_passengers_on_board integer;
    declare v_plane_locationID varchar(50);
    declare v_airport_locationID varchar(50);
    declare v_pilotID varchar(50);
    declare v_done integer default false;

    declare cur_pilots cursor for
        select personID from pilot where commanding_flight = ip_flightID;
    declare continue handler for not found set v_done = true;

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
    if v_current_progress < v_max_legs then
        leave sp_main;
    end if;

    select locationID into v_plane_locationID
    from airplane
    where tail_num = v_support_tail;

    if v_plane_locationID is null then
        leave sp_main;
    end if;

    select locationID into v_airport_locationID
    from airport
    where locationID = v_plane_locationID;

    if v_airport_locationID is null then
       leave sp_main;
    end if;

    select count(*) into v_passengers_on_board
    from person p join passenger ps on p.personID = ps.personID
    where p.locationID = v_plane_locationID;

    if v_passengers_on_board > 0 then
        leave sp_main;
    end if;

    open cur_pilots;
    recycle_loop: loop
        fetch cur_pilots into v_pilotID;
        if v_done then
            leave recycle_loop;
        end if;

        update pilot
        set commanding_flight = NULL
        where personID = v_pilotID;

        update person
        set locationID = v_airport_locationID
        where personID = v_pilotID;

    end loop;
    close cur_pilots;

	-- Ensure that the flight is on the ground
    -- Ensure that the flight does not have any more legs
    
    -- Ensure that the flight is empty of passengers
    
    -- Update assignements of all pilots
    -- Move all pilots to the airport the plane of the flight is located at

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
