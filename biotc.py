# -*- coding: utf-8 -*-
import argparse
import asyncio
import json
import os
import re
import sys
import time

import aiohttp
from pyquery import PyQuery
from jinja2 import Environment, FileSystemLoader

card_requests = {}
STEAM_ID_FILE_NAME = "SteamID.txt"
DEBUG = False

class Card:
	def __init__(self, name):
		self.name = name
		self.bot_inventory = 0
		self.bot_inventory_pending = 0
		self.user_inventory = 0
		self.price = 0
		self.trade_url = ""
		self.li_class = ""

	def __str__(self):
		return "  {} x {} a {} Credits, owned: {}".format(self.bot_inventory + self.bot_inventory_pending, self.name, self.price, self.user_inventory)

class Set:
	def __init__(self, appid, name):
		self.appid = appid
		self.name = name
		self.complete_sets = 0
		self.total_cost = 0
		self.progress = 0
		self.progress_class = ""
		self.standard_price = 0
		self.cards = []

	def __str__(self):
		return "[" + self.name + "]\n" + "\n".join(str(c) for c in self.cards)

	def bot_inventory_is_empty(self):
		for card in self.cards:
			if card.li_class == "":
				return False
		return True
		# return all(c.bot_inventory + c.bot_inventory_pending < 2 for c in self.cards)

	def user_inventory_is_empty(self):
		return all(c.user_inventory < 1 for c in self.cards)

	def is_complete(self):
		for c in self.cards:
			if c.user_inventory < 1:
				return False
		return True

	def update_complete_sets(self):
		while self.is_complete():
			self.complete_sets += 1
			for c in self.cards:
				c.user_inventory -= 1

	def calculate_total_cost(self):
		self.total_cost = sum(c.price for c in self.cards if c.user_inventory < 1)

	def set_progress_class(self):
		own_cards = len(list(filter(lambda c: c.user_inventory > 0, self.cards)))
		self.progress = own_cards / len(self.cards)
		if self.progress < 0.4:
			self.progress_class = "is-danger"
		elif self.progress < 0.8:
			self.progress_class = "is-warning"
		else:
			self.progress_class = "is-success"

	def set_card_classes(self):
		for card in self.cards:
			if card.user_inventory > 1:
				card.li_class = "surplus"
			elif card.user_inventory > 0:
				card.li_class = "owned"
			# elif card.bot_inventory + card.bot_inventory_pending < 2:
			elif card.bot_inventory < 2:
				card.li_class = "unavailable"


async def is_steam_id_64(id_or_name):
	steam_id64_regex = r"^[0-9]{17}$"
	return bool(re.match(steam_id64_regex, id_or_name))

async def get_steam_id64_from_name(name):
	print("The given Steam ID has an invalid format. Trying to resolve it as a Steam Community profile name...")
	async with aiohttp.ClientSession() as session:
		async with session.get("https://steamcommunity.com/id/" + name + "/?xml=1") as response:
			if response.status == 200:
				xml = PyQuery(await response.read(), parser="xml")
				return xml("steamID64").text()

			print("The given Steam ID or profile name could not be resolved. Please enter the Steam ID64 manually.")
			sys.exit(1)

def save_steam_id(steam_id):
	with open(STEAM_ID_FILE_NAME, "w", encoding="utf8") as file:
		file.write(steam_id)

async def fetch(session, url):
	async with session.get(url) as response:
		return await response.text()

def filter_card_stock_value(raw_string):
	return [int(s) for s in list(raw_string) if s.isdigit()]

def compare_card(inventory_name, card_name):
	inventory_name = inventory_name.strip()
	return inventory_name == card_name or inventory_name == card_name + " (Trading Card)"

def get_card_amount_in_inventory(inventory, item_data, card_name):
	count = 0
	for ele in item_data:
		if compare_card(ele["name"], card_name):
			instance_id = ele["instanceid"]
			class_id = ele["classid"]
			# Every card is a separate inventory item, they don't stack. That's why amount is not reliable.
			for value in inventory["assets"]:
				if value["classid"] == class_id and value["instanceid"] == instance_id:
					# In case they stack in the future parse the amount instead of just +1
					count += int(value["amount"])

	return count

def to_int(string):
	try:
		return int("".join(filter(str.isdigit, string)))
	except ValueError:
		return 0

def owned(inventory, card):
	for ele in inventory:
		if compare_card(ele["name"], card):
			return True
	return False

async def Start():
	timestamp = time.time()

	parser = argparse.ArgumentParser(description="BioTC by Bioruebe (https://bioruebe.com), 2014-2022, Version 3.1.1, released under a BSD 3-clause style license.\n\nBioTC is a small application to simplify trading Steam Trading Cards with the SteamCardExchange bot by comparing the user's Steam inventory with the available cards on steamcardexchange.net")
	parser.add_argument("-n", "--name", action="store", type=str, default=None, help="Use specified Steam ID64 instead of reading it from " + STEAM_ID_FILE_NAME)
	parser.add_argument("-l", "--limit", action="store", type=int, default=-1, help="Stop searching after n sets have been found")
	args = parser.parse_args()

	parser.print_help()
	print("\n-----------------------------------------------------------------------------\n")

	if args.name is None:
		try:
			with open(STEAM_ID_FILE_NAME, encoding="utf-8") as f:
				args.name = f.read()
			if not await is_steam_id_64(args.name):
				args.name = await get_steam_id64_from_name(args.name)
				print("Saving resolved SteamID to file '" + STEAM_ID_FILE_NAME + "'")
				save_steam_id(args.name)
		except:
			pass

		if args.name is None:
			print("Error: Could not read SteamID from file. Make sure the file '" + STEAM_ID_FILE_NAME + "' contains a valid SteamID.")
			sys.exit(1)
	elif not await is_steam_id_64(args.name):
		args.name = await get_steam_id64_from_name(args.name)

	result = {
		"sets": [],
		"steamID": args.name,
		"cardCount": 0,
		"gameCount": 0,
		"completeSets": 0,
		"processingTime": 0,
		"time": 0
	}

	async with aiohttp.ClientSession() as session:
		print("Loading Steam inventory of user " + args.name)
		url = f"https://steamcommunity.com/inventory/{args.name}/753/6?l=english&count=5000"

		if DEBUG:
			with open("data.json", encoding="utf8") as json_file:
				cardData = json.load(json_file)
		else:
			raw_json = await fetch(session, url)
			cardData = json.loads(raw_json)

		# print(cardData)
		if cardData is None or not cardData["success"]:
			if cardData and cardData["Error"]:
				print("Error: " + cardData["Error"])
				print("Profile URL is " + url)
			sys.exit("Invalid JSON data received. Aborting.")

		game_ids = set()
		for card in cardData["descriptions"]:
			# Ignore emoticons, backgrounds
			if "Trading Card" not in card["type"]:
				# print(card["name"] + " is not a trading card.")
				continue

			appid = card["market_fee_app"]
			game_ids.add(appid)

			# print(card)
			if card["marketable"] < 1:
				# print(card["name"] + " is not marketable and cannot be traded with the bot.")
				continue

			try:
				game_cards = card_requests[appid]
				game_cards.append(card)
			except KeyError:
				card_requests[appid] = [card]

		i = 0
		result["gameCount"] = len(game_ids)
		for appid, inventory in card_requests.items():
			print(f"Processing {appid}")
			url = f"https://www.steamcardexchange.net/index.php?inventorygame-appid-{appid}"
			resp = await fetch(session, url)
			time.sleep(0.5)
			dom = PyQuery(resp)
			info_box = dom(".flex.flex-col.justify-center.p-5.gap-y-1").children()
			game_name = info_box.eq(0).text()
			card_items = dom.items(".grid .flex-col")
			card_set = Set(appid, game_name)
			card_set.standard_price = to_int(info_box.eq(1).text().split("/")[1])

			# print(inventory)
			for item in card_items:
				divs = item.find("div")
				card = Card(divs.eq(0).text().strip())
				if card.name == "":
					# print("[Warning] Invalid card name: " + card.name)
					continue

				price_info = divs.eq(1).children()
				stock = filter_card_stock_value(price_info.eq(0).text())
				card.bot_inventory = stock[0]
				if len(stock) > 1:
					card.bot_inventory_pending = stock[1]

				card.price = to_int(price_info.eq(1).text())
				if card.price < 1:
					card.price = card_set.standard_price

				trade_url = item.find("a")
				card.trade_url = trade_url.attr("href") if trade_url else None
				card.user_inventory = get_card_amount_in_inventory(cardData, inventory, card.name)
				card_set.cards.append(card)

			card_set.update_complete_sets()
			card_set.calculate_total_cost()
			card_set.set_progress_class()
			card_set.set_card_classes()
			card_set.cards.sort(key=lambda c: (c.user_inventory, 10 - c.bot_inventory))

			result["completeSets"] += card_set.complete_sets
			if card_set.user_inventory_is_empty():
				print("User has " + str(card_set.complete_sets) + " complete sets, but no surplus cards in inventory")
				continue

			if card_set.bot_inventory_is_empty():
				print("Bot has no unowned cards (at normal price) for this set")
				continue

			print(card_set)
			result["sets"].append(card_set)

			i += 1
			if args.limit > 0 and i >= args.limit:
				break

		print("\nProcessing complete.")
		if DEBUG:
			return
		env = Environment(loader=FileSystemLoader("."))
		template = env.get_template("template.html")

		result["cardCount"] = sum(len(list(filter(lambda c: c.user_inventory < 1, s.cards))) for s in result["sets"])
		result["processingTime"] = "{:.1f}".format(time.time() - timestamp)
		result["time"] = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime())

		print("Creating HTML file")
		html = template.render(result)

		file = open("Cards.html", "w", encoding="utf-8")
		file.write(html)
		file.close()

		print("Opening generated file")
		os.startfile("Cards.html")

if __name__ == '__main__':
	loop = asyncio.get_event_loop()
	loop.run_until_complete(Start())