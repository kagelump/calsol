# Converting the main code to use datetime objects as well instead of just time objects
# Took out defaults from the iter functions
import time, math
from datetime import datetime
from models.energy import defaultModel, load_data, GPSCoordinate#, powerConsumption
from models.Predictor import powerGeneration
# function 1: Given velocity, find energy
# Default start: Now, end: 5 PM (17:00)
# energy change=energy generated-energy consumed
def calc_dE(velocity, latitude, longitude, altitude, start_time=time.strftime("%Y %m %d %H:%M", time.localtime()), end_time="17:00", cloudy=0):
    
	# Must convert end_time into a proper string 
	# Format: Year Month Day Hour:Min
	if end_time == "17:00":
		end_time = time.strftime("%Y %m %d", time.localtime()) + " 17:00"
	it = iter_dE(velocity, latitude, longitude, start_time, end_time, cloudy)
	for (done, dE) in it:
		if done:
			return dE
			
def iter_dE(velocity, latitude, longitude, start_time, end_time, cloudy):
	# Time Objects for Kevin's Program
	# Arguments should be in this format: "Year Month Day Hour:Min"
	# "2011 10 11 14:00"
	st = time.strptime(start_time, "%Y %m %d %H:%M")
	et = time.strptime(end_time, "%Y %m %d %H:%M")

	# Datetime Objects for Wesley's Program
	# Arguments should be in this format: "Year Month Day Hour:Min"
	# "2011 10 11 14:00"
	dST = datetime.strptime(start_time, "%Y %m %d %H:%M")
	dET = datetime.strptime(end_time, "%Y %m %d %H:%M")
	
	it = defaultModel.energy_loss_iterator(velocity,
                                           latitude,
                                           longitude,
                                           time.mktime(et)-time.mktime(st))
	for (done, losses) in it:
		yield (False, -losses)
		if done:
			break
	yield (True, powerGeneration(latitude, velocity, dST, dET, cloudy) - losses)

def calc_V(energy, latitude, longitude, altitude, start_time = time.strftime("%Y %m %d %H:%M", time.localtime()), end_time="17:00", cloudy=0):

	# Must convert end_time into a proper string 
	# Format: Year Month Day Hour:Min
	if end_time == "17:00":
		end_time = time.strftime("%Y %m %d", time.localtime()) + " 17:00"
	it = iter_V(energy, latitude, longitude, altitude, start_time, end_time, cloudy)
	for (done, velocity) in it:
		if done:
			return velocity
 
# function 2: Given energy, find velocity
def iter_V(energy, latitude, longitude, altitude, start_time, end_time, cloudy):
    # Start with an arbitrary average velocity... say...50 km/h
	velocity_guess = 50.0
    # error_bound
	error = 0.01
    # limit the number of iterations in case newton's method diverges
	iteration_limit = 200
	current_iteration = 0
	dv = 0.01
	# Time Objects
	st = time.strptime(start_time, "%Y %m %d %H:%M")
	et = time.strptime(end_time, "%Y %m %d %H:%M")
	dt = time.mktime(et) - time.mktime(st)
	# Datetime Objects
	dST = datetime.strptime(start_time, "%Y %m %d %H:%M")
	dET = datetime.strptime(end_time, "%Y %m %d %H:%M")
	
	start = GPSCoordinate(latitude, longitude, altitude)
    # We try to find a velocity such that the energy generated - the energy
    # consumed = the specified energy change. In order to do this, we start
    # with a guess for the correct velocity and use Newton's method to get
    # closer and closer to the correct velocity. Newton's method is a method
    # to approximate the root of a function f(x) by starting with a guess of
    # the root and repeatedly updating the guess by finding the tangent to f(x)
    # at the guess and then finding the intersection of that tangent and the x
    # axis. This x-value of this intersection point is the new guess.
	while current_iteration < iteration_limit:
        energy_gen = powerGeneration(latitude, velocity_guess, dST, dET, cloudy)
        energy_loss = powerConsumption(start, velocity_guess, dt)
        energy_change = energy_gen - energy_loss
        if math.fabs(energy_change - energy) < error:
			yield (True, velocity_guess)
			print 'answer=',velocity_guess
			break
		else:
			# Update velocity guess value
			energy_gen = powerGeneration(latitude, velocity_guess+dv, dST, dET, cloudy)
			energy_loss = powerConsumption(start, velocity_guess+dv, dt)
			print 'powerGeneration: ', energy_gen
			print 'powerConsumption: ', energy_loss
			
			E_prime = ((energy_gen - energy_loss) - energy_change) / dv
			velocity_guess = velocity_guess - (energy_change - energy) / E_prime
			current_iteration += 1
			yield (False, velocity_guess)
	
	if not(math.fabs(energy_change - energy) < error):
        # Sometime's Newton's method diverges, so we use a more reliable naive 
		# method if Newton's fails to converge after the set amount of iterations.
        
		# Reset velocity_guess
        velocity_guess = 50.0
        # Reset current_iteration
        current_iteration = 0
        # Change limit
        iteration_limit = 1000
        # Start with some increment amount
        increment_amount = 25.0
        # Hold onto our previous guesses just in case...
        prev_guess = 0
        # We assume that energy generated - energy consumed generally decreases
        # when velocity increases. So when the calculated energy change - the
        # desired change in energy at the guess velocity is positive, we increase
        # the guess velocity to get closer to the correct velocity. On the other
        # hand, if the calculated energy change - the desired change in energy at
        # the guess velocity is negative, we decrease the guess velocity to get
        # closer to the correct velocity. Everytime we change the direction in
        # which we increment the guess velocity, we know we have overshot the
        # correct velocity, so we half the increment amount to zero in on the
        # correct velocity.
        while current_iteration < iteration_limit:
            energy_gen = powerGeneration(latitude, velocity_guess, dST, dET, cloudy)
            energy_loss = powerConsumption(start, velocity_guess, dt)
            energy_change = energy_gen - energy_loss
            if math.fabs(energy_change-energy) < error:
                if velocity_guess < 0:
                    print "Input energy too high -> velocity ended up negative."
                yield (True, velocity_guess)
                print 'answer=',velocity_guess
                break
            elif energy_change-energy > 0:
                #check to see if we overshot:
                if velocity_guess+increment_amount == prev_guess:
                    increment_amount = increment_amount/2
                prev_guess = velocity_guess
                velocity_guess += increment_amount
            else:
                #check to see if we overshot:
                if velocity_guess-increment_amount == prev_guess:
                    increment_amount = increment_amount/2
                prev_guess = velocity_guess
                velocity_guess -= increment_amount
            current_iteration += 1
            yield (False, velocity_guess)
	if not(math.fabs(energy_change - energy) < error):
        # DOOM
        print "Max iterations exceeded. Try different inputs."
        yield (True, -1)

# Dummy test functions
##def powerGeneration(latitude, velocity, start_time, end_time, cloudy):
##    energy_change = (1-cloudy)*(time.mktime(end_time)-time.mktime(start_time))
##    return energy_change

def powerConsumption((latitude, longitude, altitude), velocity, time):
    energy_eaten = 0.3*time*velocity
    return energy_eaten


# Main Caller and Loop Function
if __name__ == '__main__':
    # Previous calculation state:
    calcType = 0
    energyState = 0
    inputVelocity = 0
    inputEnergy = 0
    endTime = "0:00"

    #initialize route database:
    load_data()
    # User input loop
    while True:
    	# Asks user whether to start a new calculation or modify the previous one
        operationType = raw_input("Enter 'n' to start a new calculation. Enter 'm' to modify a previous calculation. ")
        if operationType=="n":
            # Starting new calculation
            calcType=raw_input("Enter 'v' to calculate the average velocity given a change in battery energy. Enter 'e' to calculate change in battery energy given an average velocity. ")
            # Calculate velocity given a change in energy
            if calcType=="v":
                inputEnergy=raw_input("Please enter the desired energy change: ")
                longitude=raw_input("Please enter your current longitude coordinate: ")
                lat=raw_input("Please enter your current latitude coordinate: ")
                alt=raw_input("Please enter your current altitude: ")
                startTime=raw_input("Please enter your desired start time. Format: 'year month day hr:min' (24 hr time) If you leave this field blank, 'now' will be the start time. ")
                if startTime=="":
                    print ("Start time defaulted to now")
                    startTime=time.strftime("%Y %m %d %H:%M",time.localtime())
                endTime=raw_input("Please enter your desired end time. Format: 'year month day hr:min' (24 hr time) If you leave this field blank, 17:00 will be the start time. ")
                if endTime=="":
                    print ("End time defaulted to today at 17:00")
					# Default endTime will be handled along the way
                    endTime="17:00"
                energyState=raw_input("Please enter the energy level (in MJ) of the batteries at the start location: ")
                cloudiness=raw_input("Please enter a projected %cloudy value [0,1]. If you leave this field blank, historical values will be used. ")
                if cloudiness=="":
                    cloudiness=-1
                print str(calc_V(float(inputEnergy),float(longitude),float(lat),float(alt),startTime,endTime,float(cloudiness))) + "km/h"
            # Calculate change in energy given a velocity
            if calcType=="e":
                inputVelocity=raw_input("Please enter the desired average velocity: ")
                longitude=raw_input("Please enter your current longitude coordinate: ")
                lat=raw_input("Please enter your current latitude coordinate: ")
                alt=raw_input("Please enter your current altitude: ")
                startTime=raw_input("Please enter your desired start time. Format: 'year month day hr:min' (24 hr time) If you leave this field blank, 'now' will be the start time. ")
                if startTime=="":
                    print ("Start time defaulted to now")
					startTime=time.strftime("%Y %m %d %H:%M",time.localtime())
                endTime=raw_input("Please enter your desired end time. Format: 'hr:min' (24 hr time) If you leave this field blank, 17:00 will be the start time. ")
                if endTime=="":
                    print ("End time defaulted to today at 17:00")
					# This'll be handled later
					endTime="17:00"
                energyState=raw_input("Please enter the energy level (in MJ) of the batteries at the start location: ")
                cloudiness=raw_input("Please enter a projected %cloudy value [0,1]. If you leave this field blank, historical values will be used. ")
                if cloudiness=="":
                    cloudiness=-1
                print str(calc_dE(float(inputVelocity),float(longitude),float(lat), float(alt), startTime,endTime,float(cloudiness))) + "MJ"
        
        elif operationType == "m" and type!=0:
            # Modifying previous calculation
            ce = raw_input("Please enter the current energy of the car: ")
            currentEnergy = float(ce)
            newEnergy = float(inputEnergy) - (currentEnergy - float(energyState))
            clouds = raw_input("Please enter a new %cloudy value [0,1]: ")
            cloudiness = float(clouds)
            newLongitude = raw_input("Please enter a new longitude value: ")
            longitude = float(newLongitude)
            newLat = raw_input("Please enter a new latitude value: ")
            lat = float(newLat)
            startTime = time.strftime("%Y %m %d %H:%M", time.localtime())
            
            if type == "v":
                # Calculate velocity given a change in energy
                print str(calc_V(newEnergy, longitude, lat, startTime, endTime, cloudiness))+ "km/h"
            else:
                # Calculate change in energy given a velocity
                print str(calc_dE(float(inputVelocity), longitude, lat, startTime, endTime, cloudiness) + (currentEnergy - float(energyState))+"MJ")
                      


