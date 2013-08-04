// scrolling plugin
jQuery.fn.scroll = function(options){
	var options = jQuery.extend({
		animSpeed: 400,
		easing:'swing',
		event:'click'
	},options);

	return this.each(function(){
		var link = jQuery(this);
		var animSpeed = options.animSpeed;
		var easing = options.easing;
		var event = options.event;
		link.bind(event,function(e){
			var block = jQuery(jQuery(this).attr('href'));
			if (block.length) {
				jQuery('html,body').stop().animate({scrollTop:block.offset().top},{queue:false, easing:easing, duration:animSpeed});
			}
			e.preventDefault();
		})
	});
}