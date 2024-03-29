CardAvailability
================

#### About

Bioruebe's Trading Card Bot Availability Checker (BioTC) is a small application to simplify trading Steam Trading Cards with the [SteamCardExchange bot](https://www.steamcardexchange.net/index.php?guide).

SteamCardExchange provides an online interface to check for available trading cards. Comparing your own card to the bot's inventory is a lengthy process though, which BioTC automates for you.

#### How it works

For every trading card in your inventory, BioTC first retrieves information about the whole card set from SteamCardExchange. Then, it searches for cards you are missing from said set and looks into the bot's inventory to compare them with the available cards. The result - a list of all missing trading cards the bot can provide - is displayed in your browser.

#### Download

Get the current prebuilt binary from the [Releases tab](https://github.com/Bioruebe/CardAvailability/releases).

Alternatively, you can simply clone the repository and run `python biotc.py`

#### Usage

Your Steam **inventory must be set to public**, otherwise BioTC will not work.

Before you can use BioTC, you must tell it which Steam profile to use for comparision. To do so, simply open the file `SteamID.txt` (or create it if it doesn't exist) and **paste your Steam ID64**.

The Steam ID64 is a **17-digit number** and can be found on your [account page](https://store.steampowered.com/account/), right below the page title.

From now on you can simply start the program and wait until your browser opens with the result page.

Previous versions of BioTC used the steam profile ID instead of the Steam ID64. On the first start of the current version, BioTC will try to get your Steam ID64 automatically. Normally, no manual action is necessary, but in case you encounter problems, please try to enter your ID manually.

##### Card set overview

After processing has finished, your standard web browser will open and display an overview of available cards missing from your inventory. For each game you will see a box with all the information and links to quickly trade with the bot:

![biotc tutorial](docs/biotc_ui_tutorial.png)

After clicking a card name to make an offer, the status is updated automatically: a green check mark is added, progress/total cost changes and the list item will become grayed out. This (along with the close icon at the top left of each box) is a temporary effect. You can reset it by reloading the page.

You can sort the boxes with the drop-down button at the top right of the page. Your sorting order will be saved locally and applied even after running biotc again or reloading the page.

Note: although the program's output looks like a web page, it isn't. **The overview does not update if the bot's inventory changes**; you have to run biotc again if you want to know the current availability. This means the card you want to trade might already be taken by someone else, if you wait too long after running biotc - but normally that is only a problem during Steam sales.

##### Command line usage

Alternatively, you can run BioTC from the command line. The following parameters can be used to further configure the tool:

| Short parameter | Long parameter | Description                                                                                                                                                             |
| --------------- | -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| -h              | --help         | List all supported command line parameters                                                                                                                              |
| -n              | --name         | Use specified Steam ID64 instead of reading it from `SteamID.txt`                                                                                                       |
| -l              | --limit        | Stop searching after `N` sets have been found                                                                                                                           |
| -d              | --delay        | Delay between requests in seconds. Setting this too low may result in a temporary ban and/or failed requests. Default is 0.5 and minimum possible value is 0.1 seconds. |