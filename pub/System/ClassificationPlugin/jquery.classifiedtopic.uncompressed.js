jQuery(function($) {
  $('.clsTopicInfoMore').live("click", function() {
    var $this = $(this),
        $container = $this.parent(),
        web = foswiki.getPreference("WEB"),
        topic = foswiki.getPreference("TOPIC"),
        pubUrlPath = foswiki.getPreference("PUBURLPATH"),
        scriptUrl = foswiki.getPreference("SCRIPTURL"),
        systemWeb = foswiki.getPreference("SYSTEMWEB"),
        loadUrl = scriptUrl+'/view/Applications/ClassificationApp/RenderClassifiedTopicView?section=more;skin=text;source='+web+'.'+topic;

    $this.blur().addClass("clsTopicInfoMoreClicked").html('<img src="'+pubUrlPath+'/'+systemWeb+'/JQueryPlugin/images/spinner.gif" />');
    $container.load(loadUrl, function() { 
      $container.effect('highlight'); 
    });
    return false;
  });
});
