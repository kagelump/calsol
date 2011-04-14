import time, math
from models.energy import powerConsumption, load_data

# function 1: Given velocity, find energy
# Default start: Now, end: 5 PM (17:00)

def calc_dE(velocity, longitude, latitude, altitude, start_time=time.strftime("%H:%M", time.localtime()), end_time="17:00", cloudy=0):
    if velocity < 0:
        print "Invalid argument to velocity. Velocity must be positive!"
        return ()
    st = time.strptime("Oct 11 " + start_time, "%b %y %H:%M")
    et = time.strptime("Oct 11 " + end_time, "%b %y %H:%M")
    energy_change = powerGeneration(latitude, velocity, st, et, cloudy) - powerConsumption((latitude, longitude, altitude), velocity, time.mktime(et)-time.mktime(st))
    return energy_change
    
# function 2: Given energy, find velocity
def calc_V(energy, longitude, latitude, altitude, start_time = time.strftime("%H:%M", time.localtime()), end_time="17:00", cloudy=0):
    # Start with an arbitrary average velocity... say...50 km/h
    velocity_guess = 50.0
    # error_bound
    error = 0.01
    # limit the number of iterations in case newton's method diverges
    iteration_limit = 200
    current_iteration = 0
    dv = 0.01
    st = time.strptime("Oct 11 " + start_time, "%b %y %H:%M")
    et = time.strptime("Oct 11 " + end_time, "%b %y %H:%M")
    # use Newton's method to estimate root:
    while current_iteration < iteration_limit:
        energy_change = powerGeneration(latitude, velocity_guess, st, et, cloudy) - powerConsumption((latitude, longitude, altitude), velocity_guess, time.mktime(et) - time.mktime(st))
        if math.fabs(energy_change - energy) < error:
            return velocity_guess
        else: 
            # Update velocity guess value
            print 'powerGeneration: ', powerGeneration(latitude, velocity_guess+dv, st, et, cloudy)
            print 'powerConsumption: ', powerConsumption((latitude, longitude, altitude), velocity_guess+dv, time.mktime(et)-time.mktime(st))
            E_prime = (powerGeneration(latitude, velocity_guess+dv, st, et, cloudy) - powerConsumption((latitude, longitude, altitude), velocity_guess+dv, time.mktime(et)-time.mktime(st)) - energy_change) / dv
            #print 'eprime: ', (powerGeneration(latitude, velocity_guess+dv, st, et, cloudy) - powerConsumption((latitude, longitude, altitude), velocity_guess+dv, time.mktime(et)-time.mktime(st)))
            velocity_guess = velocity_guess - (energy_change - energy) / E_prime
            current_iteration+=1
    
    # If it gets here, it's probably diverging, so we try another way
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
    # This better converge
    while current_iteration < iteration_limit:
        energy_change = powerGeneration(latitude, velocity_guess, st, et, cloudy) - powerConsumption((latitude, longitude, altitude), velocity_guess, time.mktime(et)-time.mktime(st))
        if math.fabs(energy_change-energy) < error:
            if velocity_guess < 0:
                print "Input energy too high -> velocity ended up negative."
                return ()
            return velocity_guess
        elif energy_change-energy > 0:
            if velocity_guess+increment_amount == prev_guess:
                increment_amount = increment_amount/2
            prev_guess = velocity_guess
            velocity_guess += increment_amount
            
        else:
            if velocity_guess-increment_amount == prev_guess:
                increment_amount = increment_amount/2
            prev_guess = velocity_guess
            velocity_guess -= increment_amount
        current_iteration += 1
        
    # DOOM
    print "Max iterations exceeded. Try different inputs."
    return ()

# Dummy test functions
def powerGeneration(latitude, velocity, start_time, end_time, cloudy):
    energy_change = (1-cloudy)*(time.mktime(end_time)-time.mktime(start_time))
    return energy_change

#def powerConsumption(longitude, latitude, velocity, time):
 #   energy_eaten = 0.3*time*velocity
  #  return energy_eaten


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
                startTime=raw_input("Please enter your desired start time. Format: 'hr:min' (24 hr time) If you leave this field blank, 'now' will be the start time. ")
                if startTime=="":
                    print ("Start time defaulted to now")
                    startTime=time.strftime("%H:%M",time.localtime())
                endTime=raw_input("Please enter your desired end time. Format: 'hr:min' (24 hr time) If you leave this field blank, 17:00 will be the start time. ")
                if endTime=="":
                    print ("End time defaulted to 17:00")
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
                startTime=raw_input("Please enter your desired start time. Format: 'hr:min' (24 hr time) If you leave this field blank, 'now' will be the start time. ")
                if startTime=="":
                    print ("Start time defaulted to now")
                startTime=time.strftime("%H:%M",time.localtime())
                endTime=raw_input("Please enter your desired end time. Format: 'hr:min' (24 hr time) If you leave this field blank, 17:00 will be the start time. ")
                if endTime=="":
                    print ("End time defaulted to 17:00")
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
            startTime = time.strftime("%H:%M", time.localtime())
            
            if type == "v":
                # Calculate velocity given a change in energy
                print str(calc_V(newEnergy, longitude, lat, startTime, endTime, cloudiness))+ "km/h"
            else:
                # Calculate change in energy given a velocity
                print str(calc_dE(float(inputVelocity), longitude, lat, startTime, endTime, cloudiness) + (currentEnergy - float(energyState))+"MJ")
                      


