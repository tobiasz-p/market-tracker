.pragma library

// BarWidgetModel.js — Helper geometry and timestamp functions for Panel.qml.

function sparklinePoints(data, w, h, topPad, botPad) {
  if (!data || data.length < 2) return [];
  var nums = [];
  for (var i = 0; i < data.length; i++) {
    var v = Number(data[i]);
    if (!isNaN(v)) nums.push(v);
  }
  if (nums.length < 2) return [];

  topPad = topPad || 2;
  botPad = botPad || 2;
  var usableH = Math.max(1, h - topPad - botPad);

  var min = nums[0], max = nums[0];
  for (var j = 1; j < nums.length; j++) {
    if (nums[j] < min) min = nums[j];
    if (nums[j] > max) max = nums[j];
  }
  var range = max - min;
  if (range <= 0) range = 1;
  var step = w / (nums.length - 1);

  var pts = [];
  for (var k = 0; k < nums.length; k++) {
    var yVal = topPad + (usableH - ((nums[k] - min) / range) * usableH);
    pts.push({ x: k * step, y: yVal, val: nums[k] });
  }
  return pts;
}

function timeAgo(epochSecs) {
  if (!epochSecs) return "";
  var diff = Math.floor(Date.now() / 1000) - epochSecs;
  if (diff < 60) return "just now";
  if (diff < 3600) return Math.floor(diff / 60) + "m ago";
  if (diff < 86400) return Math.floor(diff / 3600) + "h ago";
  if (diff < 604800) return Math.floor(diff / 86400) + "d ago";
  var d = new Date(epochSecs * 1000);
  return (d.getMonth() + 1) + "/" + d.getDate();
}
