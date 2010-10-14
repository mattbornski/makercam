﻿package com.partkart{		import flash.geom.Point;		public class PostProcessor{				var cutlist:Array;		var output:String;		var cutteron:Boolean = false;		var tools:Array;		var currenttool:int;				public function PostProcessor(cuts:Array):void{			cutlist = cuts;		}				public function process():String{			if(cutlist.length == 0){				return null;			}						output = "(Generated by PartKam Version 0.04)\n\n";						if(Global.unit == "in"){				output += "G20 G90 G40\n";			}			else{				output += "G21 G90 G40\n";			}						tools = new Array();			for each(var cut:* in cutlist){				if(tools.indexOf(cut.tooldiameter) == -1){					tools.push(cut.tooldiameter);				}			}						tools.sort(Array.NUMERIC | Array.DESCENDING);			currenttool = -1;						for each(cut in cutlist){				// only output gcode for processed cutobjects				if(cut.processed == false){					continue;				}				if(cut is ProfileCutObject){					output += processProfile(cut);				}				else if(cut is PocketCutObject){					output += processPocket(cut);				}				else if(cut is FollowPathCutObject){					output += processFollowPath(cut);				}				else if(cut is DrillCutObject){					output += processDrill(cut);				}			}						output += "G0 Z" + cut.safetyheight + "\n";			output += "M5\n";			output += "M30\r\n";						return output;		}				protected function processProfile(cut:ProfileCutObject):String{						var tool:int = tools.indexOf(cut.tooldiameter);						var factor:int = 10/Global.tolerance;			if(factor < 1){				factor = 1;			}						var loops:Array = cut.rootpath.getChildren();						if(loops.length == 0){				return "";			}						var profile:String = "\n("+cut.name+")\n";						for each(var loop:CutPath in loops){				var seglist:Array = loop.seglist;				if(seglist.length == 0){					continue;				}				profile += "G0 Z" + cut.safetyheight + "\n";								if(tool != currenttool){					profile += "T"+tool+" M6\n";					currenttool = tool;				}								if(cutteron == false){					profile += "G17\n";					profile += "M3\n";					cutteron = true;				}				// rapid to inital position				var X:Number = seglist[0].p1.x+cut.docx;				var Y:Number = seglist[0].p1.y-cut.docy;								if(Global.unit == "cm"){					X *= 10;					Y *= 10;				}								profile += "G0 X"+Global.toFixed(X, factor)+" Y"+Global.toFixed(Y,factor)+"\n";								// because of tabs, we can't reuse each slice				var slice:String;								// now build up multiple slices until target depth is reached				var surface:Number = Global.toFixed(cut.stocksurface, factor);				var depth:Number = surface;				var target:Number = Global.toFixed(cut.targetdepth, factor);				var stepdown:Number = Global.toFixed(cut.stepdown, factor);								var splitcut:CutPath = loop.processTabs();								while(depth > target){					depth -= stepdown;					if(depth < target){						depth = target;					}										// floating point error tends to creep in at this point					depth = Global.toFixed(depth, factor);										slice = getLoopGcode(splitcut,cut.feedrate,cut.docx,cut.docy,depth,cut.targetdepth,cut.plungerate);										profile += "G1 Z"+depth+" F"+cut.plungerate+"\n";					profile += slice;				}			}						return profile;		}				protected function processPocket(cut:PocketCutObject):String{			var tool:int = tools.indexOf(cut.tooldiameter);						var factor:int = 10/Global.tolerance;			if(factor < 1){				factor = 1;			}						var loops:Array = cut.rootpath.getChildren();						if(loops.length == 0){				return "";			}						var pocket:String = "\n("+cut.name+")\n";			var prevloop:CutPath;						var depth:Number = Global.toFixed(cut.stocksurface, factor);						var X:Number;			var Y:Number;						while(depth > cut.targetdepth){				depth -= cut.stepdown;								depth = Global.toFixed(depth, factor);								if(depth < cut.targetdepth){					depth = cut.targetdepth;				}								prevloop = loops[0];								for each(var loop:CutPath in loops){					var seglist:Array = loop.seglist;					if(seglist.length == 0){						continue;					}										X = seglist[0].p1.x+cut.docx;					Y = seglist[0].p1.y-cut.docy;										if(Global.unit == "cm"){						X *= 10;						Y *= 10;					}										var depthdiff:int = loop.pocketdepth - prevloop.pocketdepth;										if(prevloop != loop && (depthdiff == -1 || depthdiff == 1) && prevloop.parent == loop && loop.getNumChildren() == 1){						// simply G1 linear move to the next position if the current container is a direct descendant of the previous one						pocket += "G1 X"+Global.toFixed(X, factor)+" Y"+Global.toFixed(Y, factor)+" F"+cut.feedrate+"\n";					}					//if(prevloop == loop || ((depthdiff != -1 && depthdiff != 1) && !(loop.parent == prevloop || prevloop.parent == loop))){					else{						pocket += "G0 Z" + cut.safetyheight + "\n";												if(tool != currenttool){							pocket += "T"+tool+" M6\n";							currenttool = tool;						}												if(cutteron == false){							pocket += "G17\n";							pocket += "M3\n";							cutteron = true;						}						// rapid to inital position						pocket += "G0 X"+Global.toFixed(X, factor)+" Y"+Global.toFixed(Y, factor)+"\n";						pocket += "G1 Z"+depth+" F"+cut.plungerate+"\n";					}					/*else{						// simply G1 linear move to the next position if the current container is a direct descendant of the previous one						pocket += "G1 X"+Global.toFixed(X, factor)+" Y"+Global.toFixed(Y, factor)+" F"+cut.feedrate+"\n";					}*/										prevloop = loop;										pocket += getLoopGcode(loop, cut.feedrate, cut.docx, cut.docy);				}			}						return pocket;		}				protected function processFollowPath(cut:FollowPathCutObject):String{			var tool:int = tools.indexOf(cut.tooldiameter);						// we want to output 1 more digit than the specified tolerances			var factor:int = 10/Global.tolerance;			if(factor < 1){				factor = 1;			}						var loops:Array = cut.rootpath.getChildren();						if(loops.length == 0){				return "";			}						var follow:String = "\n("+cut.name+")\n";						for each(var loop:CutPath in loops){				var seglist:Array = loop.seglist;				if(seglist.length == 0){					continue;				}								// since each "z-slice" is the same, we'll just build it once and re-use				var slice:String = getLoopGcode(loop,cut.feedrate,cut.docx,cut.docy);								// now build up multiple slices until target depth is reached				var surface:Number = Global.toFixed(cut.stocksurface, factor);				var depth:Number = surface;								while(depth > cut.targetdepth){										follow += "G0 Z" + cut.safetyheight + "\n";										if(tool != currenttool){						follow += "T"+tool+" M6\n";						currenttool = tool;					}										if(cutteron == false){						follow += "G17\n";						follow += "M3\n";						cutteron = true;					}					// rapid to inital position					var X:Number = seglist[0].p1.x+cut.docx;					var Y:Number = seglist[0].p1.y-cut.docy;										if(Global.unit == "cm"){						X *= 10;						Y *= 10;					}										follow += "G0 X"+Global.toFixed(X, factor)+" Y"+Global.toFixed(Y,factor)+"\n";										depth -= cut.stepdown;										depth = Global.toFixed(depth, factor);										if(depth < cut.targetdepth){						depth = cut.targetdepth;					}										follow += "G1 Z"+depth+" F"+cut.plungerate+"\n";					follow += slice;				}			}						return follow;		}				protected function processDrill(cut:DrillCutObject):String{			var tool:int = tools.indexOf(cut.tooldiameter);						// we want to output 1 more digit than the specified tolerances			var factor:int = 10/Global.tolerance;			if(factor < 1){				factor = 1;			}						var dlist:Array = cut.dlist;			if(dlist.length == 0){				return "";			}						var drill:String = "\n("+cut.name+")\n";			var surface:Number = Global.toFixed(cut.stocksurface, factor);			var depth:Number = surface;							for each(var drillpoint:Point in dlist){				depth = surface;								drill += "G0 Z" + cut.safetyheight + "\n";								if(tool != currenttool){					drill += "T"+tool+" M6\n";					currenttool = tool;				}								if(cutteron == false){					drill += "G17\n";					drill += "M3\n";					cutteron = true;				}								// rapid to drill point				var X:Number = drillpoint.x+cut.docx;				var Y:Number = drillpoint.y-cut.docy;								if(Global.unit == "cm"){					X *= 10;					Y *= 10;				}								drill += "G0 X"+Global.toFixed(X, factor)+" Y"+Global.toFixed(Y,factor)+"\n";								while(depth > cut.targetdepth){					depth -= cut.stepdown;											depth = Global.toFixed(depth, factor);										if(depth < cut.targetdepth){						depth = cut.targetdepth;					}										drill += "G1 Z"+depth+" F"+cut.plungerate+"\n";					drill += "G1 Z"+surface+" F"+cut.plungerate+"\n";				}			}						return drill;		}				// gets the gcode for a single loop		protected function getLoopGcode(cut:CutPath, feedrate:Number, docx, docy, depth:Number = NaN, targetdepth:Number = NaN, plungerate:Number = NaN):String{			var seglist:Array = cut.seglist;						var tablist:Array;			var tab:Tab;						if(cut.tabs && cut.tabs.length > 0 && !isNaN(depth) && !isNaN(targetdepth) && !isNaN(plungerate)){				tablist = cut.tabs.slice();				tab = tablist.shift();			}						var factor:int = 10/Global.tolerance;			if(factor < 1){				factor = 1;			}						var slice:String = "";			var feedchanged:Boolean = true;						for(var i:int=0; i<seglist.length; i++){								// tabs				if(tab && Global.toFixed(tab.tabheight+targetdepth, factor) > depth){					// check for tab start					if(tab.p1 == seglist[i].p1){						slice += "G1 Z"+Global.toFixed(tab.tabheight+targetdepth, factor)+" F"+plungerate+"\n";						feedchanged = true;					}										// check for tab end					if(tab.p2 == seglist[i].p1){						slice += "G1 Z"+depth+" F"+plungerate+"\n";						feedchanged = true;												if(tablist.length == 0){							tab = null;						}						else{							tab = tablist.shift();						}					}				}								var X:Number = seglist[i].p2.x+docx;				var Y:Number = seglist[i].p2.y-docy;								X = Number(Global.toFixed(X,factor));				Y = Number(Global.toFixed(Y,factor));								// turn cm to mm				if(Global.unit == "cm"){					X *= 10;					Y *= 10;				}								if(seglist[i] is CircularArc && seglist[i].getLength() > Global.tolerance){											var I:Number = seglist[i].center.x-seglist[i].p1.x;					var J:Number = seglist[i].center.y-seglist[i].p1.y;										I = Number(Global.toFixed(I, factor));					J = Number(Global.toFixed(J, factor));										// turn cm to mm					if(Global.unit == "cm"){						I *= 10;						J *= 10;					}										if(isClockwise(seglist[i])){						slice += "G2 X"+X+" Y"+Y+" I"+I+" J"+J;					}					else{						slice += "G3 X"+X+" Y"+Y+" I"+I+" J"+J;					}				}				else{					slice += "G1 X"+X+" Y"+Y;				}				if(feedchanged){					slice += " F"+feedrate+"\n";					feedchanged = false;				}				else{					slice += "\n";				}			}						return slice;		}				protected function isClockwise(arc:CircularArc):Boolean{			var norm1:Point = new Point(arc.p1.x-arc.center.x,arc.p1.y-arc.center.y);			var norm2:Point = new Point(arc.p2.x-arc.center.x,arc.p2.y-arc.center.y);						var angle:Number = Global.getAngle(norm1,norm2);						/*if(Math.abs(angle) > Math.PI/2){				trace('not good!');			}*/						if(angle < 0){				return true;			}			else{				return false;			}		}	}}