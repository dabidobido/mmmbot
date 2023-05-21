# Mandragora Mania Madness Bot

This is for automating the Mandragora Mania Madness mini game. This only reads packets and does not inject them, and uses input commands to simulate the client actually playing the game normally. But still, use at your own risk!

# How to Use

1. Talk to Chacharoon
2. Start a game (first game always takes very long to load)
3. Quit and Talk to Chacharoon again
4. Go to the player selection sub menu (I couldn't find an incoming or outgoing packet when I went between the main menu and player selection sub menu)
4. //mmmbot start
5. Select player (Only tested logic against Green Thumb Moogle. Quite possible algorithm will lose in some instances). 

# Commands

use //mmmbot to send commands

## mmmbot start <number_of_jingly_to_get>: 

> mmmbot start 0

Starts automating until you get the amount of jingly specified. 300 is default. Set to 0 automate until you tell it to stop.

## mmmbot stop

Will stop the automation.

## mmmbot setdelay (keypress / keydownup / ack / waitforack) (number)

Configures the delay for the various events

keypress is the delay between a key down and up event and the next key down and up event.

keydownup is the delay between a key down and key up event.

ack is the delay between sending out an ack packet and the bot trying to take a turn

waitforack is the delay the bot will wait if no ack packet is sent (usually when a turn doesn't update the score)

## mmmbot debug 

Toggles between printing debug messages to console or not. Default is off.

## mmmbot buykey <number>

Buys <number> of Dial Key #FOs. Use when not in a menu.

# Version History
1.2.5:
- Fix fill without bust function
- Reset on zone change since logout doesn't trigger when kicked out to character select

1.2.4:
- Fix skip corner condition. Need to check center pieces

1.2.3:
- Add some error handling for lag when going back to main menu

1.2.2:
- Add some error handling

1.2.1:
- Change everything to use os.clock() instead of os.time() which only has 1 sec precision.
- Fix some bugs with navigation helper.
- Add more logic for not taking the 4th corner under certain conditions.

1.2.0:
- Add in support for Chacharoon in Windurst Waters and Southern Sandoria
- Remove the coroutines cos it seems to crash luacore.dll. Bonus that the navigation is faster now.
- Reduced time for first action after new game/round to 10 secs. This means it is very important to do the first game with long load manually before using this.

1.1.3:
- Remove some extra logic that prevented bot from filling up sides
- Skip getting corner position under certain conditions
- Don't claim position if enemy gets 3 in a line without busting trying to block player
- Still lose some games but it's good enough!

1.1.2:
- Fix logic that tried to block enemy win but busted
- Try to fill in center areas safely first
- Try to get corner that forces an opponent move first
- Try to win by converting opponent pieces first

1.1.1:
- Fix logic that claimed area that let enemy win the next turn

1.1.0:
- Smarter bot
- Buy keys in bulk

1.0.0: 
- First version. Algorithim is quite stupid so will lose sometimes.
