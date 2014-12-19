/**
 * Copyright (c) 2014, Bioruebe
 * 
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 * 
 * 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * 
 * 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * 
 * 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
**/ 

package ;

import haxe.Curl;
import haxe.ds.StringMap;
import haxe.Http;
import haxe.Json;
import haxe.Serializer;
import haxe.Timer;
import haxe.Unserializer;
import neko.Lib;
import neko.vm.Thread;
import sys.io.File;
import sys.io.Process;

/**
 * ...
 * @author Bioruebe
 */

class Main 
{
	static var iRequests:Int = 0;
	static var sSteamID:String = "";
	static var sBasePath:String = ".\\";
	static var iGameCount:Int = 0;
	static var iBetweenRequests = 0.5;
	
	//static var cards:Array<CardInfo> = new Array();
	static var cardRequests:StringMap<Array<CardInfo>> = new StringMap();
	static var cardOffers:Array<CardOffer> = new Array();
	static var gameNames:StringMap<String>;
	static var cookie = "";
	
	static function main() 
	{
		var timestamp:Float = Timer.stamp();
		Bio.Header("Bioruebe's Trading Card Bot Availability Checker", "1.04", "A simple tool to compare a Steam Inventory with available cards at http://www.steamcardexchange.net/index.php?inventory", "[-n:name]\n	-n		Use 'name' as steamID instead of reading it from file\n\n!Cards already in the inventory are skipped.\n!Only sets of which at least one card is owned are considered.\n!If a complete set is in the inventory, no cards will be searched. Craft a badge, then try again.\n");
		
		getCookie();
		
		trace(cookie);
		
		//Sys.exit(0);
		
		// Load appID data
		//try {
			//var serializedString = File.getContent(sBasePath + "appIDs.db");
			//gameNames = Unserializer.run(serializedString);
			////trace("unserialised");
		//}
		//catch (err:Dynamic){
			gameNames = new StringMap();
		//}
		
		var arg:String = Sys.args().pop();
		if (arg != null) {
			var pos:Int = arg.indexOf("-n:");
			if (pos != -1) {
				sSteamID = arg.substr(pos + 3);
			}
		}		
		
		// Get SteamID
		try {
			if (sSteamID == "") {
				sSteamID = File.getContent(sBasePath + "steamID.txt");
				if (sSteamID == "") throw "NO_USER";
			}
			
		}
		catch (err:Dynamic) {
			trace("Can not read SteamID from file. Make sure the file 'steamID.txt' contains a valid SteamID.");
			Sys.exit(1);
		}
		
		Request("http://steamcommunity.com/id/" + sSteamID + "/inventory/json/753/6", OnSteamCards);
		
		var message:HttpRequest;
		while (iRequests > 0) {
			message = Thread.readMessage(true);
			message.dataHandler(message);
			iRequests--;
		}
		
		//File.saveContent(sBasePath + "appIDs.db", Serializer.run(gameNames));
		
		trace("\n\n\n\n\n");
		
		// Print results and create HTML file
		var html:String = "<h2><a href=\"http://steamcommunity.com/tradeoffer/new/?partner=83905207&token=tEx7-bXd\">Make Offer</a></h2><h3><a href= \"http://www.steamcardexchange.net/index.php?profile\">Your Credits</a></h3>";
		var gameName:String;
		for (o in cardOffers) {
			gameName = gameNames.get(o.appID);
			if (html.indexOf(gameName) == -1) {
				if (html.indexOf("<ul>") != -1) html += "</ul>";
				html += "<br><b><a href=\"http://steamcommunity.com/id/" + sSteamID + "/gamecards/" + o.appID + "\">" + gameName + "</a></b><br><ul>";
			}
			html += "<li>" + o.amount + " x <a href=\"" + o.tradeLink + "\">" + o.name + "</a> a <a href=\"" + o.url + "\">" + o.price + " Credits</a>";
			trace(gameName + ": " + o.amount + " x " + o.name + " a " + o.price + " Credits");
		}
		html += "</ul><br><br><b>" + cardOffers.length + "</b> cards found in total. " + sSteamID.charAt(0).toUpperCase() + sSteamID.substr(1) + "'s inventory contained trading cards from " + iGameCount + " different games.<br><br><small>Created by <a href=\"http://bioruebe.com/cardcheck\">Bioruebe's Trading Card Bot Availability Checker</a>, " + Date.now() + "</small>";
		
		// Write to HTML file and execute
		File.saveContent(sBasePath + "Cards.html", html);
		new Process("cmd", ["/c " + sBasePath + "Cards.html"]);
		
		trace("\nCompleted! Processing cards for " + iGameCount + " games took a total of " + Std.string(Std.int(Math.fceil((Timer.stamp() - timestamp) * 100)) / 100) + " seconds.");
		trace(cardOffers.length + " missing cards available for trade.\n");
	}
	
	static function OnSteamCards(request:HttpRequest) {
		var data:String = request.response;
		var cardData:Dynamic = null;
		
		// Parse JSON
		try {
			cardData = Json.parse(data);
			if (cardData.success != true) throw "INVALID_JSON";
			
		}
		catch (err:Dynamic) {
			trace("Error: Invalid JSON data. Aborting.");
			Sys.exit(1);
			return;
		}
		
		for (obj in Reflect.fields(cardData.rgDescriptions)) {
			var card:CardInfo = Reflect.field(cardData.rgDescriptions, obj);
			if (Reflect.fields(card).length < 1) continue;
			
			// Ignore emoticons, backgrounds
			if (card.type.indexOf("Trading Card") < 0) {
				//trace(card.name + " is not a trading card.");
				continue;
			}
			
			// Insert appid and array into map
			var allCards:Array<CardInfo> = cardRequests.get(card.market_fee_app);
			if (allCards == null) {
				var cards:Array<CardInfo> = new Array();
				cards.push(card);
				cardRequests.set(card.market_fee_app, cards);
			}
			else {
				allCards.push(card);
			}
			//cards.push(card);
		}
		var i:Int = 0;
		for (key in cardRequests.keys()) {
			trace("Processing " + key);
			//for (k in cardRequests.get(key)) {
				//trace(k.market_fee_app + " - " + k.name);
			//}
			
			//break;
			Request("http://www.steamcardexchange.net/index.php?inventorygame-appid-" + key, OnTradeOffer, cardRequests.get(key));
			Sys.sleep(iBetweenRequests);
			cardRequests.remove(key);
			i++;
			//if (i > 4) break;
		}
		//trace(cardRequests);
	}
	
	static function OnTradeOffer(request:HttpRequest) {
		//trace("OnTradeOffer");
		iGameCount++;
		//trace(request.response);
		var data:String = request.response;
		//File.saveContent("test.html", data);
		
		// Get name to appid
		if (!gameNames.exists(request.additionalData[0].market_fee_app)) {
			gameNames.set(request.additionalData[0].market_fee_app, Bio.StringBetween(request.response, "<h2 class=\"empty\">", "</h2>"));
		}
		
		var available:Array<String> = Bio.StringAllBetween(data, "<div class=\"inventory-game-card-item\">", "</div></div>");
		for (html in available) {
			if ((html.indexOf("card-amount red") != -1) || (html.indexOf("card-amount gray") != -1)) {
				//trace("Red!");
				continue;
			}
			
			var name:String = StringTools.htmlUnescape(Bio.StringBetween(html, "<span class=\"card-name gray\">", "</span>"));
			if (name == "") continue;
			
			if (InArray(request.additionalData, name)) {
				trace(name + " - Owned");
				continue;
			}
			
			var amount:Int = Std.parseInt(Bio.StringBetween(html, "Stock:", "</span>"));
			var price:Int = Std.parseInt(Bio.StringBetween(html, "Price: ", " "));
			var quickTradeLink:String = Bio.StringBetween(html, "element-button\"><a href=\"", "\"");
			
			cardOffers.push(new CardOffer(name, amount, price, request.url, request.additionalData[0].market_fee_app, quickTradeLink));
			//trace(amount + " x " + name + " a " + price + " Credits");
			//trace(cardOffers.pop());
		}
		
	}
	
	static function InArray(array:Array<CardInfo>, name:String) {
		for (ele in array) {
			//trace(ele.name + " <---> " + name);
			if (ele.name == name || ele.name == name + " (Trading Card)") return true;
		}
		return false;
	}
	
	static function Request(url:String, dataHandler:HttpRequest->Void, ?additionalData:Dynamic):Void {
		iRequests ++;
		trace(">Sending request: " + url);
		//var request:HttpRequest = new HttpRequest(url);
		////request.addHeader("Accept", "text/html");
		//request.dataHandler = onData;
		//request.onStatus = function(code:Int) { trace("Status: " + code); }
		//request.onError = function (message:String) { trace("Error: " + message); }
		
		var t = Thread.create(RequestThread);
		t.sendMessage(Thread.current());
		t.sendMessage(new HttpRequest(url, dataHandler, additionalData));
	}
	
	static function RequestThread() {
		var main:Thread = Thread.readMessage(true);
		var request:HttpRequest = Thread.readMessage(true);
		
		request.response = Curl.get(request.url, null, ["Cookie:" + cookie]);
		var name = request.url.substr(request.url.lastIndexOf("/") + 1);
		if (name.indexOf("?") != -1) name = name.substr(name.lastIndexOf("?") + 1);
		//File.saveContent(name + ".html", request.response);
		
		main.sendMessage(request);
	}
	
	// Retrieve session id, without the server will not send data
	static function getCookie() {
		// cURL for haxe does not include all features, so a normal http request has to be used
		trace("Waiting for session ID");
		var request = new Http("http://www.steamcardexchange.net");
		request.request(false);
		
		while (request.responseData == null) {
			Sys.sleep(0.1);
		}
		
		//trace(request.responseHeaders);
		
		cookie = request.responseHeaders.get("Set-Cookie");
	}
}