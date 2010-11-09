# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2010 Michael Daum http://michaeldaumconsulting.com
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

package Foswiki::Plugins::ClassificationPlugin;
use strict;
use Foswiki::Contrib::DBCacheContrib::Search ();

use vars qw( 
  $VERSION $RELEASE $NO_PREFS_IN_TOPIC $SHORTDESCRIPTION
  $doneInitCore $doneInitServices $baseTopic $baseWeb $css
);

$VERSION = '$Rev: 1340 $';
$RELEASE = '1.00';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'A topic classification plugin and application';

$css = '<link rel="stylesheet" href="%PUBURLPATH%/%SYSTEMWEB%/ClassificationPlugin/styles.css" media="all" />';
  
###############################################################################
sub initPlugin {
  ($baseTopic, $baseWeb) = @_;

  Foswiki::Func::registerTagHandler('HIERARCHY', \&handleHIERARCHY);
  Foswiki::Func::registerTagHandler('ISA', \&handleISA);
  Foswiki::Func::registerTagHandler('SUBSUMES', \&handleSUBSUMES);
  Foswiki::Func::registerTagHandler('SIMILARTOPICS', \&handleSIMILARTOPICS_DEPRECATED); # use SolrPlugin instead
  Foswiki::Func::registerTagHandler('CATINFO', \&handleCATINFO);
  Foswiki::Func::registerTagHandler('TAGINFO', \&handleTAGINFO);
  Foswiki::Func::registerTagHandler('DISTANCE', \&handleDISTANCE);

  Foswiki::Func::registerRESTHandler('splitfacet', \&restSplitFacet );
  Foswiki::Func::registerRESTHandler('renametag', \&restRenameTag );
  Foswiki::Func::registerRESTHandler('normalizetags', \&restNormalizeTags );

  Foswiki::Contrib::DBCacheContrib::Search::addOperator(
    name=>'SUBSUMES', 
    prec=>4,
    arity=>2,
    exec=>\&OP_subsumes,
  );
  Foswiki::Contrib::DBCacheContrib::Search::addOperator(
    name=>'ISA', 
    prec=>4,
    arity=>2,
    exec=>\&OP_isa,
  );
  Foswiki::Contrib::DBCacheContrib::Search::addOperator(
    name=>'DISTANCE', 
    prec=>5,
    arity=>2,
    exec=>\&OP_distance,
  );

  Foswiki::Func::addToZone('head', 'CLASSIFICATIONPLUGIN', $css, 'JQUERYPLUGIN::FOSWIKI');

  # SMELL this is not reliable as it depends on plugin order
  # if (Foswiki::Func::getContext()->{SolrPluginEnabled}) {
  if ($Foswiki::cfg{Plugins}{SolrPlugin}{Enabled}) {
    require Foswiki::Plugins::SolrPlugin;
    Foswiki::Plugins::SolrPlugin::registerIndexTopicHandler(\&indexTopicHandler);
    Foswiki::Plugins::SolrPlugin::registerIndexAttachmentHandler(\&indexAttachmentHandler);
  }

  $doneInitCore = 0;
  $doneInitServices = 0;
  return 1;
}

###############################################################################
sub indexTopicHandler {
  initCore();
  return Foswiki::Plugins::ClassificationPlugin::Core::indexTopicHandler(@_);
}

###############################################################################
sub indexAttachmentHandler {
  initCore();
  return Foswiki::Plugins::ClassificationPlugin::Core::indexAttachmentHandler(@_);
}

###############################################################################
sub initCore {
  return if $doneInitCore;
  $doneInitCore = 1;
  require Foswiki::Plugins::ClassificationPlugin::Core;
  Foswiki::Plugins::ClassificationPlugin::Core::init($baseWeb, $baseTopic);

#  require Foswiki::Plugins::ClassificationPlugin::Access;
#  Foswiki::Plugins::ClassificationPlugin::Access::init($baseWeb, $baseTopic);
}

###############################################################################
sub initServices {
  return if $doneInitServices;
  $doneInitServices = 1;

  initCore();

  require Foswiki::Plugins::ClassificationPlugin::Services;
  Foswiki::Plugins::ClassificationPlugin::Services::init($baseWeb, $baseTopic);
}

###############################################################################
sub beforeSaveHandler {
  initCore();
  return Foswiki::Plugins::ClassificationPlugin::Core::beforeSaveHandler(@_);
}

###############################################################################
sub afterSaveHandler {
  initCore();
  return Foswiki::Plugins::ClassificationPlugin::Core::afterSaveHandler(@_);
}

###############################################################################
# SMELL: I'd prefer a proper finishHandler, alas it does not exist
sub modifyHeaderHandler {
  Foswiki::Plugins::ClassificationPlugin::Core::finish(@_)
    if $doneInitCore;
  Foswiki::Plugins::ClassificationPlugin::Services::finish(@_)
    if $doneInitServices;
}

###############################################################################
# perl api
sub getHierarchy {
  initCore();
  return Foswiki::Plugins::ClassificationPlugin::Core::getHierarchy(@_);
}

###############################################################################
sub OP_subsumes {
  initCore();
  return Foswiki::Plugins::ClassificationPlugin::Core::OP_subsumes(@_);
}

###############################################################################
sub OP_isa {
  initCore();
  return Foswiki::Plugins::ClassificationPlugin::Core::OP_isa(@_);
}

###############################################################################
sub OP_distance {
  initCore();
  return Foswiki::Plugins::ClassificationPlugin::Core::OP_distance(@_);
}

###############################################################################
sub handleHIERARCHY {
  initCore();
  return Foswiki::Plugins::ClassificationPlugin::Core::handleHIERARCHY(@_);
}

###############################################################################
sub handleISA {
  initCore();
  return Foswiki::Plugins::ClassificationPlugin::Core::handleISA(@_);
}

###############################################################################
sub handleSUBSUMES {
  initCore();
  return Foswiki::Plugins::ClassificationPlugin::Core::handleSUBSUMES(@_);
}

###############################################################################
sub handleCATINFO {
  initCore();
  return Foswiki::Plugins::ClassificationPlugin::Core::handleCATINFO(@_);
}

###############################################################################
sub handleTAGINFO {
  initCore();
  return Foswiki::Plugins::ClassificationPlugin::Core::handleTAGINFO(@_);
}

###############################################################################
sub handleDISTANCE {
  initCore();
  return Foswiki::Plugins::ClassificationPlugin::Core::handleDISTANCE(@_);
}

###############################################################################
sub handleSIMILARTOPICS_DEPRECATED {
  initCore();
  return Foswiki::Plugins::ClassificationPlugin::Core::handleSIMILARTOPICS(@_);
}


###############################################################################
sub restSplitFacet {
  initServices();
  return Foswiki::Plugins::ClassificationPlugin::Services::splitFacet(@_);
}

###############################################################################
sub restRenameTag {
  initServices();
  return Foswiki::Plugins::ClassificationPlugin::Services::renameTag(@_);
}

###############################################################################
sub restNormalizeTags {
  initServices();
  return Foswiki::Plugins::ClassificationPlugin::Services::normalizeTags(@_);
}

1;
