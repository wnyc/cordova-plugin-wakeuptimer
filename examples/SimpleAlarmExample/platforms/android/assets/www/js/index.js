/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */
var app = {
    // Application Constructor
    initialize: function() {
        this.bindEvents();
    },
    // Bind Event Listeners
    //
    // Bind any events that are required on startup. Common events are:
    // 'load', 'deviceready', 'offline', and 'online'.
    bindEvents: function() {
        document.addEventListener('deviceready', this.onDeviceReady, false);
    },
    // deviceready Event Handler
    //
    // The scope of 'this' is the event. In order to call the 'receivedEvent'
    // function, we must explicitly call 'app.receivedEvent(...);'
    onDeviceReady: function() {
        app.receivedEvent('deviceready');
    },
    // Update DOM on a Received Event
    receivedEvent: function(id) {
        alert('Device is Ready');
		var parentElement = document.getElementById(id);
        var listeningElement = parentElement.querySelector('.listening');
        var receivedElement = parentElement.querySelector('.received');

        listeningElement.setAttribute('style', 'display:none;');
        receivedElement.setAttribute('style', 'display:block;');

        console.log('Received Event: ' + id);
    }
};
var testAlarm = {
	setAlarm:function(caseNo){
		/* var d = new Date();
		if(caseNo == 1){
			d.setMinutes(d.getMinutes() - 2);
		} else if(caseNo == 2){
			d.setMinutes(d.getMinutes() + 2);
		} else if(caseNo == 3){
			d.setMinutes(d.getMinutes() + 5);
		}
		var optionsAlarm = {
			type : 'onetime',
			time : { hour : d.getHours(), minute : d.getMinutes() },
			message : this.get('message'),
			sound : this.get('sound'),
			action : this.get('action')
		}
		window.wakeuptimer.wakeup(
			function(result) {
				if (result.type==='wakeup') {
					alert('wakeup alarm detected--' + result.extra);
				} else if(result.type==='set'){
					alert('wakeup alarm set--' + result);
				} else {
					alert('wakeup unhandled type (' + result.type + ')');
				}
			},
			function() {
				alert('Error Handler');
			},
			optionsAlarm
		); */
	}
}
app.initialize();