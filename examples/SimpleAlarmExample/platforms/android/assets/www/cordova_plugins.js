cordova.define('cordova/plugin_list', function(require, exports, module) {
module.exports = [
    {
        "file": "plugins/org.nypr.cordova.wakeupplugin/www/wakeup.js",
        "id": "org.nypr.cordova.wakeupplugin.Wakeup",
        "clobbers": [
            "wakeuptimer"
        ]
    }
];
module.exports.metadata = 
// TOP OF METADATA
{
    "org.nypr.cordova.wakeupplugin": "0.1.0"
}
// BOTTOM OF METADATA
});