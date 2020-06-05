﻿/*   SoundManager 2: Javascript Sound for the Web   ----------------------------------------------   http://schillmania.com/projects/soundmanager2/   Copyright (c) 2008, Scott Schiller. All rights reserved.   Code licensed under the BSD License:   http://www.schillmania.com/projects/soundmanager2/license.txt   V2.77a.20080901   Flash 8 / ActionScript 2 version   Compiling AS to Flash 8 SWF using MTASC (free compiler - http://www.mtasc.org/):   mtasc -swf soundmanager2.swf -main -header 16:16:30 SoundManager2.as -version 8   ActionScript Sound class reference (Macromedia):   http://livedocs.macromedia.com/flash/8/main/wwhelp/wwhimpl/common/html/wwhelp.htm?context=LiveDocs_Parts&file=00002668.html   *** NOTE ON LOCAL FILE SYSTEM ACCESS ***   Flash security allows local OR network access, but not both   unless explicitly whitelisted/allowed by the flash player's   security settings.*/import flash.external.ExternalInterface; // wooclass SoundManager2 extends MovieClip {	static var app:SoundManager2;	private var sounds:Array;	private var soundObjects:Array;	private var timer;	private var timerInterval:Number;	private var pollingEnabled:Boolean;	private var playerID:String;	private var secureDomain:String;	private var sID:String;		public function SoundManager2() {		_init();	}		public function sendEvent(event:String, object:Object) {		return ExternalInterface.call('ppc.flash.callMethod', playerID || 1, 'event', event, object);	}		public function callJS(method:String, data:Object) {		return ExternalInterface.call('ppc.flash.callMethod', playerID || 1, method, data);	}		public function callMethod() {		var method:String = String(arguments.shift());    this[method].apply(this, arguments);	}		private function checkProgress() {    var bL = 0;    var bT = 0;    var nD = 0;    var nP = 0;    var oSound = null;    for (var i = 0, j = sounds.length; i < j; i++) {      oSound = soundObjects[sounds[i]];      bL = oSound.getBytesLoaded();      bT = oSound.getBytesTotal();      nD = oSound.duration || 0; // can sometimes be null with short MP3s? Wack.      nP = oSound.position;      if (bL && bT && bL != oSound.lastValues.bytes) {        oSound.lastValues.bytes = bL;        sendEvent("progress",{bytesLoaded:bL,bytesLoaded:bT,totalTime:nD});      }      if (typeof nP != 'undefined' && nP != oSound.lastValues.position) {        oSound.lastValues.position = nP;        sendEvent("playheadUpdate",{playheadTime: nP,totalTime:nD});        // if position changed, check for near-end        if (oSound.didJustBeforeFinish != true && oSound.loaded == true && oSound.justBeforeFinishOffset > 0 && nD-nP <= oSound.justBeforeFinishOffset) {          // fully-loaded, near end and haven't done this yet..          sendEvent("justbeforecomplete",{timeLeft:(nD-nP)});          oSound.didJustBeforeFinish = true;        }      }    }  }		private function onClipLoad(o, bSuccess) {    checkProgress(); // ensure progress stats are up-to-date    // force duration update (doesn't seem to be always accurate)    sendEvent("progress",{			bytesLoaded: o.getBytesLoaded(),			totalBytes : o.getBytesTotal(),			totalTime  : o.duration		});    sendEvent("ready", {			state: bSuccess ? 1 : 0		});  }		private function onID3(o:Object) {    // --- NOTE: BUGGY? ---    // --------------------    // TODO: Investigate holes in ID3 parsing - for some reason, Album will be populated with Date if empty and date is provided. (?)    // ID3V1 seem to parse OK, but "holes" / blanks in ID3V2 data seem to get messed up (eg. missing album gets filled with date.)    // iTunes issues: onID3 was not called with a test MP3 encoded with iTunes 7.01, and what appeared to be valid ID3V2 data.    // May be related to thumbnails for album art included in MP3 file by iTunes. See http://mabblog.com/blog/?p=33    var id3Data  = [];    var id3Props = [];    for (var prop in o.id3) {      id3Props.push(prop);      id3Data.push(o.id3[prop]);      // writeDebug('id3['+prop+']: '+this.id3[prop]);    }    sendEvent("id3",{			properties: id3Props,			data: id3Data		});    // unhook own event handler, prevent second call (can fire twice as data is received - ID3V2 at beginning, ID3V1 at end.)    // Therefore if ID3V2 data is received, ID3V1 is ignored.    soundObjects[sID].onID3 = null;  }  private function registerOnComplete() {		var _self = this;    soundObjects[sID].onSoundComplete = function() {      this.didJustBeforeFinish = false; // reset      _self.sendEvent("complete");    }  }  public function setPosition(nSecOffset, isPaused) {    var s = soundObjects[sID];    s.lastValues.position = s.position;    s.start(nSecOffset,s.lastValues.nLoops||1); // start playing at new position    if (isPaused) s.stop();  }  public function loadSound(sURL, bStream, bAutoPlay) {    if (typeof bAutoPlay == 'undefined') bAutoPlay = false;    // checkProgress();    var s = soundObjects[sID];		var _self = this;    s.onID3 = function() {			_self.onID3(this);		};    s.onLoad = function(bSuccess) {			_self.onClipLoad(this, bSuccess);		}    s.loaded = true;    s.loadSound(sURL, bStream);    s.didJustBeforeFinish = false;    if (bAutoPlay != true) {      s.stop(); // prevent default auto-play behaviour      // writeDebug('auto-play stopped');    } else {      // writeDebug('auto-play allowed');    }    registerOnComplete(sID);  }  public function unloadSound(sURL) {    // effectively "stop" loading by loading a tiny MP3    var s = soundObjects[sID];    s.onID3 = null;    s.onLoad = null;    s.loaded = false;    s.loadSound(sURL,true);    s.stop(); // prevent auto-play    s.didJustBeforeFinish = false;  }  public function createSound(justBeforeFinishOffset) {    soundObjects[sID] = new Sound();    var s = soundObjects[sID];    s.setVolume(100);    s.didJustBeforeFinish = false;    s.sID = sID;    s.paused = false;    s.loaded = false;    s.justBeforeFinishOffset = justBeforeFinishOffset||0;    s.lastValues = {      bytes: 0,      position: 0,      nLoops: 1    };    sounds.push(sID);  }  public function destroySound() {    // for the power of garbage collection! .. er, Greyskull!    var s = (soundObjects[sID] || null);    if (!s) return false;    for (var i = 0; i < sounds.length; i++) {      if (sounds[i] == s) {	      sounds.splice(i,1);        continue;      }    }    s = null;    delete soundObjects[sID];  }  public function stopSound(bStopAll) {    // stop this particular instance (or "all", based on parameter)    if (bStopAll) {      _root.stop();    }		else {      soundObjects[sID].stop();      soundObjects[sID].paused = false;      soundObjects[sID].didJustBeforeFinish = false;    }  }  public function startSound(nLoops, nMsecOffset) {    registerOnComplete();    var s = soundObjects[sID];    s.lastValues.paused = false; // reset pause if applicable    s.lastValues.nLoops = (nLoops||1);    s.start(nMsecOffset, nLoops);  }  public function pauseSound() {    var s = soundObjects[sID];    if (!s.paused) {      // reference current position, stop sound      s.paused = true;       s.lastValues.position = s.position;      s.stop();    }		else {      // resume playing from last position      // writeDebug('resuming - playing at '+s.lastValues.position+', '+s.lastValues.nLoops+' times');      s.paused = false;      s.start(s.lastValues.position/1000,s.lastValues.nLoops);    }  }  public function setPan(nPan) {    soundObjects[sID].setPan(nPan);  }  public function setVolume(nVol) {    soundObjects[sID].setVolume(nVol);  }  public function setPolling(bPolling) {    pollingEnabled = bPolling;    if (timer == null && pollingEnabled) {			var _self = this;      timer = setInterval(function() {				_self.checkProgress();			}, timerInterval);    }		else if (timer && !pollingEnabled) {      clearInterval(timer);      timer = null;    }  }  public function _init() {		sounds = [];	  soundObjects = [];	  timer = null;	  timerInterval = 50;	  pollingEnabled = false;	  sID = "soundmgr2";    // OK now stuff should be available		playerID = _root.playerID;		secureDomain = _root.secureDomain;		if (secureDomain)			System.security.allowDomain(secureDomain);		    try {      ExternalInterface.addCallback('callMethod', this, callMethod);			sendEvent("init", {state: 1, sandboxType: System.security['sandboxType']});    } catch (error) {      // d'oh!    }  }		// entry point  static function main(mc) {    app = new SoundManager2();  }	}