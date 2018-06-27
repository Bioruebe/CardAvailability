# -*- coding: utf-8 -*-
import argparse
import asyncio
import json
import os
import sys
import time
from datetime import datetime

import aiohttp
from pyquery import PyQuery

card_requests = {}

async def fetch(session, url):
	async with session.get(url) as response:
		return await response.text()

def owned(inventory, card):
	for ele in inventory:
		if ele["name"] == card or ele["name"] == card + " (Trading Card)":
			return True
	return False

async def Start():
	timestamp = time.time()

	parser = argparse.ArgumentParser(description="")
	parser.add_argument("-n", "--name", action="store", type=str, default=None, help="")
	args = parser.parse_args()

	if args.name is None:
		try:
			f = open("SteamID.txt")
			args.name = f.read()
		except:
			pass
	if args.name is None:
		sys.exit("Can not read SteamID from file. Make sure the file 'steamID.txt' contains a valid SteamID.")

	html = "<h2><a href=\"http://steamcommunity.com/tradeoffer/new/?partner=83905207&token=tEx7-bXd\">Make Offer</a></h2><h3><a href= \"http://www.steamcardexchange.net/index.php?profile\">Your Credits</a></h3>"
	async with aiohttp.ClientSession() as session:
		print("Loading Steam inventory")
		url = "http://steamcommunity.com/id/" + args.name + "/inventory/json/753/6"
		raw_json = await fetch(session, url)
		cardData = json.loads(raw_json)
		# print(cardData)
		if cardData is None or not cardData["success"]:
			sys.exit("Invalid JSON data received. Aborting.")

		for obj in cardData["rgDescriptions"]:
			card = cardData["rgDescriptions"][obj]
			# Ignore emoticons, backgrounds
			if "Trading Card" not in card["type"]:
				# print(card["name"] + " is not a trading card.")
				continue
			# print(card)

			try:
				game_cards = card_requests[card["market_fee_app"]]
				game_cards.append(card)
			except KeyError:
				card_requests[card["market_fee_app"]] = [card]

		# j = 0
		for appid, inventory in card_requests.items():
			print("Processing " + appid)
			url = "https://www.steamcardexchange.net/index.php?inventorygame-appid-" + appid
			resp = await fetch(session, url)
			time.sleep(0.5)
			dom = PyQuery(resp)
			game_name = dom("h2").text()
			card_items = dom.items(".inventory-game-card-item")
			# print(inventory)
			i = 0
			for item in card_items:
				name = item.find(".card-name").text().strip()
				if name == "":
					continue
				# print(len(name))
				available = item.find(".green, .orange")
				if not available:
					continue
				stock = "".join(filter(str.isdigit, item.find(".card-amount").text()))
				price = "".join(filter(str.isdigit, item.find(".card-price").eq(1).text()))
				trade_link = item.find(".button-blue").attr("href")

				if owned(inventory, name):
					print(name + " - Owned")
					continue

				print(stock + " x " + name + " a " + price + " Credits")
				if i == 0:
					html += "<br><b><a href=\"http://steamcommunity.com/id/" + args.name + "/gamecards/" + appid + "\">" + game_name + "</a></b>&nbsp;<small><a href=\"https://www.steamcardexchange.net/index.php?gamepage-appid-" + appid + "\">Showcase</a></small><br><ul>"
				i += 1

				html += "<li>" + stock + " x <a href=\"" + trade_link + "\">" + name + "</a> a <a href=\"" + url + "\">" + price + " Credits</a>"

			if i > 0:
				html += "</ul>"

			# j += 1
			# if j > 5:
			# 	break

		html += "</ul><br><br><b>" + str(html.count("<ul>")) + "</b> cards found in total. " + args.name[0].upper() + args.name[1:] + "'s inventory contained trading cards from " + str(html.count("gamepage-appid")) + " different games.<br><br><small>Created by <a href=\"http://bioruebe.com/cardcheck\">Bioruebe's Trading Card Bot Availability Checker</a>, " + str(datetime.now()) + "</small>"
		file = open("Cards.html", "w", encoding="utf-8")
		file.write(html)
		file.close()
		os.startfile("Cards.html")

if __name__ == '__main__':
	loop = asyncio.get_event_loop()
	loop.run_until_complete(Start())