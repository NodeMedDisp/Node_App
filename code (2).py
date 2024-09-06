import time
import board
import digitalio
import neopixel
from adafruit_debouncer import Debouncer
import displayio
import terminalio
import adafruit_displayio_ssd1306
from adafruit_display_text import label
import busio
import microcontroller
import aesio
import pwmio
from adafruit_motor import servo
import nonblocking_serialinput as nb_serialin
import random


DOSE_TIME = 10/3600 #1.0 # in hours
dose_time_s = DOSE_TIME * 3600
PILLS_TOTAL = 3 # This is the total number of pills/cycles the program will dispense
pills = 0 # number of pills taken, initalizated to 0

DOSE_AMOUNT = 25 #mg of morphine in pill

display_dose_time = 0 #timer for displaying countdown
display_sleep_time = 0 #timer for display sleep
confirm_time = 0 #timer for confirming pain rating
confirm_time_diff = 0 #difference between confirm_time and the current time

pill_log = []

unlocked = False

pin = 1234 #password that allows input of commands

proto = True #False for the actual product; True for the proto board development



# get list of pins; go to pinout for all their functions
'''
for pin in dir(microcontroller.pin):
    if isinstance(getattr(microcontroller.pin, pin), microcontroller.Pin):
        print("".join(("microcontroller.pin.", pin, "\t")), end=" ")
        for alias in dir(board):
            if getattr(board, alias) is getattr(microcontroller.pin, pin):
                print("".join(("", "board.", alias)), end=" ")
    print()'''

my_input = nb_serialin.NonBlockingSerialInput(echo=False)

#Create NeoPixel LED object

pixel = neopixel.NeoPixel(board.NEOPIXEL, 1)

pixel.brightness = 0.01

button = digitalio.DigitalInOut(board.A2)
button.direction = digitalio.Direction.INPUT
button.pull = digitalio.Pull.UP

switch = Debouncer(button)

# create a PWMOut object on Pin D9.
pwm = pwmio.PWMOut(board.D9, duty_cycle=2 ** 15, frequency=50)
my_servo = servo.Servo(pwm) # Create a servo object, my_servo.

displayio.release_displays()

i2c = board.I2C()

WIDTH = 128
HEIGHT = 64  
BORDER = 5

display_bus = displayio.I2CDisplay(i2c, device_address=0x3d, reset=board.D10)
display = adafruit_displayio_ssd1306.SSD1306(display_bus, width=WIDTH, height=HEIGHT)


#Blinky sanity check

'''while True:
    pixel.fill((255, 50, 50))
    time.sleep(0.3)
    pixel.fill((50, 255, 100))
    time.sleep(0.3)
    pixel.fill((0, 0, 0))
    time.sleep(0.3)'''

color = True
    

#initialization of data log file
try:
    with open("/kiwicap.csv", "a") as fp:
        fp.write("Pill, Time(s), Time(days:hours:minutes:seconds),Pain\n")
        fp.flush()
        fp.close()
except OSError as e:
    if proto:
        #flash purple if error in opening file
        if color:
            pixel.fill((255,0,255)) # PURPLE
        else:
            pixel.fill((0,0,0)) # DARK
        color = not color
        time.sleep(0.5)
    else:
        pass


# Get values in config file and set the local values to match them
def readConfig():
    global DOSE_TIME
    global PILLS_TOTAL
    global dose_time_s
    
    try:
        with open("/kiwiconfig.txt", "r") as fp:
            lines = fp.readlines()
            for line in lines:
                print(line)
            PILLS_TOTAL = int((lines[0]).strip("Pills="))
            DOSE_TIME = float((lines[1]).strip("Dose_time="))
            DOSE_AMOUNT = float((lines[2]).strip("Dose_amount="))
            dose_time_s = DOSE_TIME*3600
            fp.close()
    except OSError as e:
        if proto:
            #flash purple if error in opening file
            if color:
                pixel.fill((255,0,255)) # PURPLE
            else:
                pixel.fill((0,0,0)) # DARK
            color = not color
            time.sleep(0.5)
        else:
            pass

# Update config file with the local values
def writeConfig():
    global PILLS_TOTAL
    global DOSE_TIME
    global DOSE_AMOUNT
    global color
    
    try:
        with open("/kiwiconfig.txt", "w") as fp:
            
            fp.write("Pills=" + str(PILLS_TOTAL) + "\n")
            fp.write("Dose_time=" + str(DOSE_TIME) + "\n")
            fp.write("Dose_amount=" + str(DOSE_AMOUNT))
            fp.flush()
            fp.close()
    except OSError as e:
        if proto:
            #flash purple if error in opening file
            if color:
                pixel.fill((255,0,255)) # PURPLE
            else:
                pixel.fill((0,0,0)) # DARK
            color = not color
            time.sleep(0.5)
        else:
            pass

def printPillLog():
    for val in pill_log:
        my_input.print(val)
    

def is_number(value):
    """
    Return true if string is a number.

    based on
    https://stackoverflow.com/questions/354038/how-do-i-check-if-a-string-is-a-number-float

    :param string value: input to check
    :return bool: True if value is a number, otherwise False.
    """
    try:
        float(value)
    except ValueError:
        # return NaN
        return False
    else:
        return True

# Function that allows input of commands
def serialRead():
    global DOSE_TIME
    global dose_time_s
    global PILLS_TOTAL
    global DOSE_AMOUNT
    global unlocked
    
    my_input.update()
    input_string = my_input.input()
    if input_string is not None:
        input_string = input_string.strip("\n")
        if len(input_string) != 0:
            
            if unlocked: # If passcode has already been put in
            
                if "hello" in input_string:
                    my_input.print("world!")
                    
                if "display sleep" in input_string:
                    display.sleep()
                
                if "display wake" in input_string:
                    display.wake()
                     
                if "get log" in input_string:
                    printPillLog()
                    
                if "get config" in input_string:
                    my_input.print("Pills=" + str(PILLS_TOTAL) + "\nDose_time=" + str(DOSE_TIME) + "\nDose_amount=" + str(DOSE_AMOUNT))
                    
                if "set dose time" in input_string:
                    str_val = input_string.strip("set dose time")
                    if is_number(str_val):
                        num_val = float(str_val)
                        if num_val <=0:
                            my_input.print("Dose time must have a positive value.")
                        else:
                            DOSE_TIME = num_val
                            dose_time_s = DOSE_TIME*3600
                            my_input.print("New dosage time set: " + str_val + " hours")
                            displayClearSecondary()
                            writeConfig()
                    else:
                        my_input.print("Unable to parse. Enter as \"set dose time [val]\"")
                     
                if "set pills" in input_string:
                    str_val = input_string.strip("set pills")
                    if is_number(str_val):
                        num_val = int(str_val)
                        if num_val <0:
                            my_input.print("Cannot have negative number of pills.")
                        else:
                            PILLS_TOTAL = num_val
                            my_input.print("New pill count set: " + str_val)
                            writeConfig()
                        
                    else:
                        my_input.print("Unable to parse. Enter as \"set pills [val]\"")
                     
                if "set dose amount" in input_string:
                    str_val = input_string.strip("set dose amount")
                    if is_number(str_val):
                        num_val = float(str_val)
                        if num_val <=0:
                            my_input.print("Dose amount must have a positive value.")
                        else:
                            DOSE_AMOUNT = num_val
                            my_input.print("New dosage amount set: " + str_val + " mg")
                            writeConfig()
                    else:
                        my_input.print("Unable to parse. Enter as \"set dose amount [val]\"")   
                        
                # Calculates maintenance dosage based on desired concentration and patient weight
                if "pk calc" in input_string:
                    str_val = input_string.strip("pk calc")
                    val_arr = str_val.split()
                    print(val_arr)
                    if len(val_arr) == 2 and int(val_arr[0])>0 and int(val_arr[1])>0:
                        conc = int(val_arr[0])
                        weight = int(val_arr[1])
                        m_dose = PKCalc(conc,weight)
                        my_input.print("Maintenance Dose: " + str(m_dose) + " mg/hr.")
                    else:
                        my_input.print("Format as \"pk calc [target concentration in mcg/L] [patient weight in kg]\" with a space between arguments. Values must be positive.")        
                
                # Calculates dose interval based on maintenance dosage (above) and dose size
                if "pk dose" in input_string:
                    str_val = input_string.strip("pk dose")
                    val_arr = str_val.split()
                    print(val_arr)
                    if len(val_arr) == 2 and float(val_arr[0])>0 and float(val_arr[1])>0:
                        dosage = float(val_arr[0])
                        pill = float(val_arr[1])
                        input_time = PKDoseTime(dosage,pill)
                        DOSE_AMOUNT = pill
                        DOSE_TIME = input_time
                        dose_time_s = DOSE_TIME*3600
                        writeConfig()
                        my_input.print(str(pill) + " mg dose every " + str(input_time) + " hours.")
                    else:
                        my_input.print("Format as \"pk dose [maintenance dose in mg/hr (find with pk calc command)] [dose amount in mg]\" with a space between arguments. Values must be positive.")
                
                if "lock" in input_string:
                    unlocked = False
                    my_input.print("Locking commands.")
                    
            
            else:
                if str(pin) in input_string:
                    unlocked = True
                    my_input.print("PIN correct. Unlocked commands.")
                else:
                    my_input.print("Locked. Please input PIN.")


def PKCalc(conc, weight): #target morphine concentration in patients body (mcg/L) and patient weight (kg)
    return ((conc*1.43*weight)/0.4) * 0.001

def PKDoseTime(dosage, pill): #maintenance dose from PKCalc (mg/hr) and pill dose size (mg)
    return pill/dosage

# Logs time and patient pain to the log file
def logToFile(val):
    
    log_str = f"{pills},{current_time:.0f},{secondsToClock(current_time,True)},{val}"

    print("Logging " + log_str)
    pill_log.append(log_str)
    try:
        with open("/kiwicap.csv", "a") as fp:
            
            fp.write(log_str + "\n")
            fp.flush()
            fp.close()
        
    except OSError as e:
        if proto:
            #yellow if error opening or writing to file
            pixel.fill((255,255,0)) # YELLOW
            print(e.errno)
            time.sleep(1)
        else:
            pass

# Writes new text to the display
def displayWrite(text, area_x, area_y, scale):
    # write to display
    text_area.text = ""
    text_area.x = area_x
    text_area.y = area_y
    text_area.scale = scale
    text_area.text = text

# Writes new secondary text to the display
def displayWriteSecondary(text, area_x, area_y, scale):
    # write to display
    text_area_secondary.text = ""
    text_area_secondary.x = area_x
    text_area_secondary.y = area_y
    text_area_secondary.scale = scale
    text_area_secondary.text = text

# Clears secondary display text
def displayClearSecondary():
    text_area_secondary.text = ""


# Function to operate all the mechanisms for dispensing a dose and recording data
def giveDose(t):
    # open pill bottle
    global last_dose_time
    global pills
    global time
    global display
    
    last_dose_time = t
    #print("time = " + str(time) + ". Last dose time = " + str(last_dose_time))
    displayWrite("Dispensing...", 25, 30, 1)
    pills = pills + 1
    time.sleep(0.5)
    
    # Display must sleep to prevent excess power from turning off display once motor starts
    # Supposedly can be fixed by running 10-20 µF cap between board power and ground
    display.sleep()
    
    # move motor
    for angle in range(0, 180, 10):  # 0 - 180 degrees, 10 degrees at a time.
        my_servo.angle = angle
        time.sleep(0.1)
    
    time.sleep(0.5)
    display.wake()

# Converts a value in seconds to a clock format for readability
def secondsToClock(t,days_bool=False):
    days = int(t // 86400)
    hours = int((t % 86400) // 3600)
    minutes = int((t % 3600) // 60)
    seconds = int(t % 60)
    
    if days_bool == False:
        text = f"{hours:02}:{minutes:02}:{seconds:02}"
    else:
        text = f"{days:02}:{hours:02}:{minutes:02}:{seconds:02}"
    return text


# Counts down time to dose and displays on screen
def displayDoseCountdown(t):
    
    # Format and display the remaining time as minutes and seconds
    if t < 0:
        t = 0
        #Only print press for pill if text is empty; doesn't repeatedly print
        if not text_area_secondary.text:
            # Refresh the display
            display.show(splash)
            displayWrite(secondsToClock(t), 15, 28, 2)
            displayWriteSecondary("Press for pill", 20, 50, 1)
    else:
        # Refresh the display
        display.show(splash)
        displayWrite(secondsToClock(t), 15, 28, 2)

# Placeholder, can be improved in future to cut power / enable low power mode for everything in the circuit
def sleepMode():
    display.sleep()

# See above
def wakeMode():
    display.wake()

# Primary function where patient will record pain
def ratePain():
    #_________________________________________________________________________________________________
    #pain rating
    print("rating pain")
    
    global switch
    global time
    global confirm_time
    global confirm_time_diff
    global pain
    
    rating = True
    wait = 0
    pain = 0
    
    displayClearSecondary()
    displayWrite("Press to rate\nyour pain", 15, 20, 1)
    
    while rating == True:
        switch.update()
        if not switch.value: # When button pressed
            
            confirm_time = time.monotonic()
            confirm_time_diff = 0
            
            while not switch.rose: # While button is being held
                                
                if confirm_time_diff >= 1.5: # If button held for 3 seconds, return pain value
                    
                    displayClearSecondary()
                    displayWrite("Pain logged: " + f"{pain}\nRelease button\nto dispense", 15, 15, 1)
                    time.sleep(1)
                    
                    return pain 
                
                #Update held time and switch state
                confirm_time_diff = time.monotonic() - confirm_time
                switch.update()
                time.sleep(0.1)
            
            # Once switch is released
            confirm_time_diff = 0
            pain = pain+1
            if pain > 10: # Pain wraparound to 1 if exceed max (10)
                pain = 1
            displayWrite(f"{pain}", 60, 25, 3)
            displayWriteSecondary("Hold to confirm", 18, 50, 1)
            wait=0
            time.sleep(0.1)
        else:
            wait=wait+1
        
        time.sleep(.1) # sleep for debounce
        
        if wait >= 50:
            pain = 0
            rating = False
            displayClearSecondary()
            displayWrite("Cancelling...", 30, 30, 1)
    return pain

# Make the display context
splash = displayio.Group()
display.show(splash)

color_bitmap = displayio.Bitmap(WIDTH, HEIGHT, 1)
color_palette = displayio.Palette(1) 
color_palette[0] = 0xFFFFFF  # White

bg_sprite = displayio.TileGrid(color_bitmap, pixel_shader=color_palette, x=0, y=0)
splash.append(bg_sprite)

# Draw a smaller inner rectangle
inner_bitmap = displayio.Bitmap(WIDTH - BORDER * 2, HEIGHT - BORDER * 2, 1)
inner_palette = displayio.Palette(1)
inner_palette[0] = 0x000000  # Black
inner_sprite = displayio.TileGrid(
    inner_bitmap, pixel_shader=inner_palette, x=BORDER, y=BORDER
)
splash.append(inner_sprite)

# Draw a label
text = ""
text_area = label.Label(terminalio.FONT, text=text, color=0xFFFFFF)
text_area.x = 15
text_area.y = 30
text_area.scale = 2  # Increase the text size by a factor of 2
splash.append(text_area)

text_secondary = ""
text_area_secondary = label.Label(terminalio.FONT, text=text, color=0xFFFFFF)
text_area_secondary.x = 15
text_area_secondary.y = 30
text_area_secondary.scale = 2  # Increase the text size by a factor of 2
splash.append(text_area_secondary)

'''# Random PK value time test
random.seed(792110674)
rand_conc = []
rand_weight = []
rand_dose = []
test_times = []
ns_time = 0

for i in range(100):
    rand_conc.append(random.uniform(10,80)) #morphine therapeutic window boundaries
    rand_weight.append(random.uniform(40,135)) #range of human body weight within about 3 standard deviations
    rand_dose.append(random.uniform(10,100)) #lowest to highest doses in this pill size

for i in range(100):
    current_time = time.monotonic()
    PKDoseTime(PKCalc(rand_conc[i], rand_weight[i]), rand_dose[i])
    ns_time = time.monotonic_ns()
    test_times.append(ns_time - current_time*pow(10,9)) #According to docs, monotonic_ns time should only be compared with
    time.sleep(0.1)										#monotonic time; not enough precision to compare ns to ns
    
print(test_times)
'''

# Must initialize last_dose_time right before main loop since time passes running above code
current_time = time.monotonic()
last_dose_time = current_time
display_sleep_time = current_time

#Read in config file for total pills and dose time
readConfig()

# Main loop
while pills < PILLS_TOTAL:
    
    if proto:
        serialRead()
    
        #blinks blue while loop is working
        if color:
            pixel.fill((0,255,255)) # LIGHT BLUE
        else:
            pixel.fill((0,0,0)) # DARK
        color = not color
    
    #get update on button state
    switch.update()
    
    #continually update current_time
    current_time = time.monotonic()
    
    
    if not switch.value: #if button pushed (down = false, up = true)
        # Reset sleep timer; this code will be found again under each button press
        display_sleep_time = current_time
        
        # Wakes up display without proceeding to other button press functions
        if not display.is_awake:
            display.wake()
            while not switch.rose: #waits until button is released and continues to update until that happens
                switch.update()
                time.sleep(0.1)
            display_sleep_time = current_time
            continue
        
        while not switch.rose: #waits until button is released and continues to update until that happens
            switch.update()
            time.sleep(0.1)
            
        if (current_time - last_dose_time) > dose_time_s: #checks if enough time has passed to allow a dose
            pain = ratePain()    
            
            if pain > 0:
       
                # ensure switch released before moving on
                while not switch.rose:
                    switch.update()
                    time.sleep(0.1)
                    
                display_sleep_time = current_time

                current_time = time.monotonic() # Update current time for accurate logging
                logToFile(pain)
                giveDose(current_time)
                if proto:
                    pixel.fill((0,255,0)) # GREEN when giving dose
                    
                display_sleep_time = current_time
            
        #if user presses button before timer is up
        else:
            display_sleep_time = current_time
            displayWrite("Too early!", 25, 30, 1)
            pixel.fill((255,0,0)) # RED
            time.sleep(2)
    
    #every second display dose countdown timer
    else:
        if (current_time - display_dose_time) >= 1:
            #print("displaying")
            displayDoseCountdown(dose_time_s - (current_time - last_dose_time))
            display_dose_time = current_time
            
        if (current_time - display_sleep_time) >= 10 and display.is_awake:
            display.sleep()
            display_sleep_time = current_time
        
    time.sleep(0.1)
        

displayWrite("Bottle Empty", 15, 30, 1)
while True:
    if proto:
        serialRead()
        time.sleep(0.1)
    else:
        time.sleep(0.1)
