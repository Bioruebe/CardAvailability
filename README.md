CardAvailability
================

####About
Bioruebe's Trading Card Bot Availability Checker (BioTC) is a small console application to simplify trading Steam Trading Cards with the SteamCardExchange bot.

SteamCardExchange provides an online interface to check for available trading cards. Comparing your own card to the bot's inventory is a lengthy process though. BioTC automatizes it for you.

####How to
First enter your Custom URL name into the SteamID.txt file. If you are unsure what it is, look at the Edit Profile page or open your public Steam profile and copy the part after id/.  (Note: Your Steam profile and inventory must be set to public, otherwise BioTC will not work.) From now on you can just start BioTC with a click on the main executable. After a few seconds of waiting, depending on your internet connection speed, the results are printed to the console window as well as opened automatically as a HTML file in your standard browser.

######Update for version 1.10
Version 1.10 fixes a problem with Windows 10 with Creator's Update installed, which prevents the final HTML file being displayed.
Due to a bug in the current haxe/neko version, building an executable using neko fails. Therefore, either keep using the old version and open `Cards.html` manually or install neko or haxe, download the current `biotc.n` file from the bin directory and run it with `neko biotc.n`.