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

//import haxe.Curl;
import com.akifox.asynchttp.HttpHeaders;
import com.akifox.asynchttp.HttpRequest;
import com.akifox.asynchttp.HttpResponse;
import haxe.ds.StringMap;
import haxe.Http;
import haxe.Json;
import haxe.Serializer;
import haxe.Timer;
import haxe.Unserializer;
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
	
	static function main() {
		var timestamp:Float = Timer.stamp();
		Bio.Header("Bioruebe's Trading Card Bot Availability Checker", "1.10", "A simple tool to compare a Steam Inventory with available cards at http://www.steamcardexchange.net/index.php?inventory", "[-n:name]\n	-n		Use 'name' as steamID instead of reading it from file\n\n!Cards already in the inventory are skipped.\n!Only sets of which at least one card is owned are considered.\n!If a complete set is in the inventory, no cards will be searched. Craft a badge, then try again.\n");
		
		gameNames = new StringMap();
		
		var arg:String = Sys.args().pop();
		if (arg != null) {
			var pos:Int = arg.indexOf("-n:");
			if (pos != -1) sSteamID = arg.substr(pos + 3);
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
		
		getCookie();
		trace(cookie);
		
		Request("http://steamcommunity.com/id/" + sSteamID + "/inventory/json/753/6", OnSteamCards);
		
		var message:HttpRequest;
		while (iRequests > 0) {
			Sys.sleep(1);
		}
		
		//File.saveContent(sBasePath + "appIDs.db", Serializer.run(gameNames));
		
		trace("\n\n\n\n\n");
		
		// Print results and create HTML file
		var html = "<h2><a href=\"http://steamcommunity.com/tradeoffer/new/?partner=83905207&token=tEx7-bXd\">Make Offer</a></h2><h3><a href= \"http://www.steamcardexchange.net/index.php?profile\">Your Credits</a></h3>";
		var gameName;
		for (o in cardOffers) {
			gameName = gameNames.get(o.appID);
			if (html.indexOf(gameName) == -1) {
				if (html.indexOf("<ul>") != -1) html += "</ul>";
				html += "<br><b><a href=\"http://steamcommunity.com/id/" + sSteamID + "/gamecards/" + o.appID + "\">" + gameName + "</a></b>&nbsp;<small><a href=\"" + StringTools.replace(o.url, "inventorygame", "gamepage") + "\">Showcase</a></small><br><ul>";
			}
			html += "<li>" + o.amount + " x <a href=\"" + o.tradeLink + "\">" + o.name + "</a> a <a href=\"" + o.url + "\">" + o.price + " Credits</a>";
			trace(gameName + ": " + o.amount + " x " + o.name + " a " + o.price + " Credits");
		}
		html += "</ul><br><br><b>" + cardOffers.length + "</b> cards found in total. " + sSteamID.charAt(0).toUpperCase() + sSteamID.substr(1) + "'s inventory contained trading cards from " + iGameCount + " different games.<br><br><small>Created by <a href=\"http://bioruebe.com/cardcheck\">Bioruebe's Trading Card Bot Availability Checker</a>, " + Date.now() + "</small>";
		
		// Write to HTML file and execute
		File.saveContent(sBasePath + "Cards.html", html);
		Sys.command("start", [sBasePath + "Cards.html"]);
		
		trace("\nCompleted! Processing cards for " + iGameCount + " games took a total of " + Std.string(Std.int(Math.fceil((Timer.stamp() - timestamp) * 100)) / 100) + " seconds.");
		trace(cardOffers.length + " missing cards available for trade.\n");
	}
	
	static function OnSteamCards(response:HttpResponse) {
		if (!response.isOK) {
			trace('HTTP error ${response.status} ${response.error})');
			Sys.exit(2);
		}
		
		var data = response.content;
		var cardData:Dynamic = null;
		
		// Parse JSON
		try {
			cardData = Json.parse(data);
			if (cardData.success != true) throw "INVALID_JSON";
			
		}
		catch (err:Dynamic) {
			trace("Error: Invalid JSON data. Aborting.");
			Sys.exit(1);
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
			var allCards = cardRequests.get(card.market_fee_app);
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
		var i = 0;
		for (key in cardRequests.keys()) {
			trace("Processing " + key);
			//for (k in cardRequests.get(key)) {
				//trace(k.market_fee_app + " - " + k.name);
			//}
			//break;
			
			Request("http://www.steamcardexchange.net/index.php?inventorygame-appid-" + key, function(response:HttpResponse) { OnTradeOffer(response, cardRequests.get(key)); }, {"Cookie": cookie } );
			Sys.sleep(iBetweenRequests);
			cardRequests.remove(key);
			i++;
			//if (i > 4) break;
		}
		//trace(cardRequests);
		iRequests--;
	}
	
	static function OnTradeOffer(response:HttpResponse, additionalData:Dynamic) {
		if (!response.isOK) {
			trace('HTTP error ${response.status} ${response.error})');
			iRequests--;
			return;
		}
		
		iGameCount++;
		var data = response.content;
		//File.saveContent("test.html", data);
		
		// Get name to appid
		if (!gameNames.exists(additionalData[0].market_fee_app)) {
			gameNames.set(additionalData[0].market_fee_app, Bio.StringBetween(data, "<h2 class=\"empty\">", "</h2>"));
		}
		
		var available = Bio.StringAllBetween(data, "<div class=\"inventory-game-card-item\">", "</div></div>");
		for (html in available) {
			if ((html.indexOf("card-amount red") != -1) || (html.indexOf("card-amount gray") != -1)) {
				//trace("Red!");
				continue;
			}
			
			var name = StringTools.htmlUnescape(Bio.StringBetween(html, "<span class=\"card-name gray\">", "</span>"));
			if (name == "") continue;
			
			if (InArray(additionalData, name)) {
				trace(name + " - Owned");
				continue;
			}
			
			var amount = Std.parseInt(Bio.StringBetween(html, "Stock:", "</span>"));
			var price = Std.parseInt(Bio.StringBetween(html, "Price: ", " "));
			var quickTradeLink = Bio.StringBetween(html, "element-button\"><a href=\"", "\"");
			
			cardOffers.push(new CardOffer(name, amount, price, response.urlString, additionalData[0].market_fee_app, quickTradeLink));
			trace(amount + " x " + name + " a " + price + " Credits");
			//trace(cardOffers.pop());
		}
		iRequests--;
	}
	
	static function InArray(array:Array<CardInfo>, name:String) {
		for (ele in array) {
			//trace(ele.name + " <---> " + name);
			if (ele.name == name || ele.name == name + " (Trading Card)") return true;
		}
		return false;
	}
	
	static function Request(url:String, dataHandler:HttpResponse->Void, ?headers:Dynamic):Void {
		iRequests++;
		trace(">Sending request: " + url);
		
		var r = new HttpRequest( { url: url, callback: dataHandler, headers: new HttpHeaders(headers)} );
		r.send();
	}
	
	// Retrieve session id, without the server will not send data
	static function getCookie() {
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