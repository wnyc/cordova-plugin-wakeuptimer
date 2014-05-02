package org.nypr.cordova.wakeupplugin;

import java.text.SimpleDateFormat;
import java.util.Date;

import org.apache.cordova.PluginResult;
import org.json.JSONException;
import org.json.JSONObject;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

public class WakeupReceiver extends BroadcastReceiver {

	private static final String LOG_TAG = "WakeupReceiver";

	@Override
	public void onReceive(Context context, Intent intent) {
		SimpleDateFormat sdf=new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");
		Log.d(LOG_TAG, "wakeuptimer expired at " + sdf.format(new Date().getTime()));
		
		if ( WakeupPlugin.connectionCallbackContext != null ) {
			JSONObject o=new JSONObject();
		    PluginResult result=null;
		    try {
		    	o.put("type", "wakeup");
		    	o.put("extra", intent.getExtras().get("extra"));
		        result = new PluginResult(PluginResult.Status.OK, o);
		    } catch (JSONException e){
		        result = new PluginResult(PluginResult.Status.ERROR, e.getMessage());
		    } finally {
		    	result.setKeepCallback(true);
		        WakeupPlugin.connectionCallbackContext.sendPluginResult(result);
		    }
		}
	}
}
