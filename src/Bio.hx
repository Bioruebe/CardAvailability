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
import haxe.macro.Context;

/**
 * Bioruebe's helper class containing various functions to be used across different projects.
 * @author Bioruebe
 */
class Bio
{

	/**
	 * Returns first string found between given start and end string.
	 * @param	string	the search string
	 * @param	start	the start string to search between
	 * @param	end		the end string to search between
	 * @return	first string found between start and end
	 */
	public static function StringBetween(string:String, start:String, end:String):String {
		var startPos:Int = string.indexOf(start);
		
		if (startPos != -1) {
			startPos += start.length;
			var endPos:Int = string.indexOf(end, startPos + 1);
			//trace(startPos + "   " + endPos);
			if(endPos != -1) return string.substring(startPos, endPos);
		}
		
		return "";
	}
	
	/**
	 * Return all strings between given start and end string.
	 * @param	string	the search string
	 * @param	start	the start string to search between
	 * @param	end		the end string to search between
	 * @return	an array of all found strings
	 */
	public static function StringAllBetween(string:String, start:String, end:String):Array<String> {
		var aReturn:Array<String> = new Array();
		var returnString:String;
		var startPos:Int;
		var endPos:Int;
		
		do {
			startPos = string.indexOf(start);
			endPos = string.indexOf(end, startPos + 1);
			if (startPos == -1 || endPos == -1) break;
			
			returnString = string.substring(startPos + start.length, endPos);
			//trace(returnString);
			aReturn.push(returnString);
			string = string.substr(endPos + end.length);
		} while (returnString != "");
		
		return aReturn;
	}
	
	/**
	 * Print standard command line tool header
	 * @param	name		Name of the program
	 * @param	version		Version of the program
	 */
	public static function Header(name:String, version:String, description:String, usage:String) {
		trace("\n\n" + name + " by Bioruebe (http://bioruebe.com), " + getBuildYear() + ", Version " + version + ", Released under the BSD 3-Clause License\n\n" + description + "\n\nUsage: " + getProgramName() + " " + usage + "\n");
	}
	
	public static function getProgramName():String {
#if sys
		var path:String = Sys.executablePath();
		return path.substr(path.lastIndexOf("\\") + 1);
#else
		return "executableName";
#end	
	}
	
	macro private static function getBuildYear() {
		return Context.makeExpr(Date.now().getFullYear(), Context.currentPos());
	}
	
}