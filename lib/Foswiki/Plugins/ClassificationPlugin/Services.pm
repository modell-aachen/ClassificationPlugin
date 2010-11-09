# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2009 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::ClassificationPlugin::Services;

use strict;

our $debug = 0;
our $baseWeb;
our $baseTopic;
use Foswiki::Plugins::DBCachePlugin::Core ();
use Foswiki::Plugins::ClassificationPlugin::Core();
use Foswiki::Func ();
use Foswiki::Sandbox ();

use constant DEBUG => 0; # toggle me

###############################################################################
sub writeDebug {
  print STDERR $_[0]."\n" if $debug;
  #Foswiki::Func::writeDebug('- ClassificationPlugin::Services - '.$_[0]) if $debug;
}

###############################################################################
sub init {
  ($baseWeb, $baseTopic) = @_;
}

###############################################################################
sub finish {
}

###############################################################################
sub normalizeTags {
  my ($session, $subject, $verb, $response) = @_;

  my $query = Foswiki::Func::getCgiQuery();
  my $theWeb = $query->param('web') || $baseWeb;
  $theWeb = Foswiki::Sandbox::untaintUnchecked($theWeb);

  my $hierarchy = Foswiki::Plugins::ClassificationPlugin::getHierarchy($theWeb);
  my $db = Foswiki::Plugins::DBCachePlugin::Core::getDB($theWeb);

  my @topicNames = sort $db->getKeys();
  my $user = Foswiki::Func::getWikiName();
  my %knownTags;
  my %foundTopics;
  foreach my $topic (@topicNames) {
    my $tags = $hierarchy->getTagsOfTopic($topic);
    next unless $tags;
    foreach my $tag (@$tags) {
      push @{$knownTags{$tag}}, $topic;
      $foundTopics{$topic} = 1;
    }
  }
  my @foundTopics = keys %foundTopics;
  my $foundTags = 0;
  foreach my $tag (sort keys %knownTags) {
    my $altTag = $tag;
    $altTag =~ s/[^a-zA-Z0-9]//g;
    next if $altTag eq $tag;
    $foundTags++;
    next unless $knownTags{$altTag};
    my $count = Foswiki::Plugins::ClassificationPlugin::Core::renameTag($altTag, $tag, $theWeb, \@foundTopics);
    #print "renamed $count topics while changing $altTag to $tag\n";
  }
  my $totalTags = scalar(keys %knownTags);
  my $foundTopics = scalar(@foundTopics);

  return "OK: rename $foundTags of $totalTags tags in $foundTopics topics\n" 
    if $foundTopics;

  return "OK\n";
}

###############################################################################
# rename a tag: 
#
# parameters
#    * from: old tag name
#    * to: new tag name
sub renameTag {
  my ($session, $subject, $verb, $response) = @_;

  my $query = Foswiki::Func::getCgiQuery();
  my $theWeb = $query->param('web') || $baseWeb;
  $theWeb = Foswiki::Sandbox::untaintUnchecked($theWeb);

  my @theFrom = $query->param('from');

  my $theTo = $query->param('to') || '';
  $theTo = Foswiki::Sandbox::untaintUnchecked($theTo);

  my @from;
  foreach my $from (@theFrom) {
    next unless $from;
    $from = Foswiki::Sandbox::untaintUnchecked($from);
    push @from, $from;
  }
  unless (@from) {
    returnRESTResult($response, 500, "undefined 'from' parameter");
    return;
  }

  my $from = '\b('.join('|', @from).')\b';
  my $count = Foswiki::Plugins::ClassificationPlugin::Core::renameTag($from, $theTo, $theWeb);

  return "OK: nothing renamed\n" unless $count;
  return "OK: renamed $count topics\n";
}

###############################################################################
# convert all topics of a TopicType to a newly created TopicType by splitting
# and distributing its facets onto newly named formfields. For example
# a Category field might hold categories of different kind. You can now
# replace the Category formfield with new ones Facet1 and Facet2 and split
# the set of categories stored in the former Category field and move them
# to Facet1 or Facet2
#
# Parameters:
#    * web: the web to process, defaults to baseWeb
#    * intopictype: input TopicType, the set of topics to be processed
#    * outtopictype: optionally change the TopicType after having split the facet
#    * form: new DataForm to be used for converted topics
#    * map: list of formfield=category items that specify the list of new facets
#           and their root node in the taxonomy
# Note: this is an admin service - only users in the AdminGroup are allowed to call it
sub splitFacet {
  my ($session, $subject, $verb, $response) = @_;

  throw("access to service not allowed")
    unless Foswiki::Func::isAnAdmin();

  my $query = Foswiki::Func::getCgiQuery();
  my $theDebug = $query->param('debug') || 0;
  $debug = ($theDebug =~ /^(1|on|yes)$/)?1:0;

  my $theWeb = $query->param('web') || $baseWeb;

  throw("web '$theWeb' does not exist")
    unless Foswiki::Func::webExists($theWeb);

  my $theInTopicType = $query->param('intopictype');
  throw Error::Simple("undefined intopictype") 
    unless defined $theInTopicType;

  my $theOutTopicType = $query->param('outtopictype') || $theInTopicType;
  my $theExcludeTopicType = $query->param('excludetopictype');

  my $theNewForm = $query->param('form');
  throw Error::Simple("unknown form $theNewForm")
    unless Foswiki::Func::topicExists(undef, $theNewForm);

  my $theMap = $query->param('map');
  throw Error::Simple("undefined map") 
    unless defined $theMap;

  writeDebug("opening web '$theWeb'");
  my $hierarchy = Foswiki::Plugins::ClassificationPlugin::getHierarchy($theWeb);
  my $db = Foswiki::Plugins::DBCachePlugin::Core::getDB($theWeb);

  my %map = ();
  foreach my $mapItem (split(/\s*,\s*/, $theMap)) {
    if ($mapItem =~ /^(.*)=(.*)$/) {
      my $fieldName = $1;
      my $categoryName = $2;
      my $cat = $hierarchy->getCategory($categoryName);
      throw Error::Simple("unknwon category $categoryName")
	unless $cat;

      writeDebug("mapping facet '$fieldName' to '$categoryName'");
      $map{$fieldName} = $cat;
    } else {
      throw Error::Simple("invalid map format $theMap at '$mapItem'")
    }
  }

  my @topicNames = sort $db->getKeys();
  my $foundTopics = 0;
  my $index = 0;
  foreach my $topicName (@topicNames) {
    my $topicObj = $db->fastget($topicName);

    my $form = $topicObj->fastget("form");
    next unless $form;

    $form = $topicObj->fastget($form);
    next unless $form;

    my $topicTypes = $form->fastget('TopicType');
    next unless $topicTypes;

    next unless $topicTypes =~ /\b$theInTopicType\b/;
    if ($theExcludeTopicType && $topicTypes =~ /$theExcludeTopicType/)  {
      writeDebug("excluding $topicName because '$topicTypes matches' '$theExcludeTopicType'");
      next;
    }

    my $cats = $hierarchy->getCategoriesOfTopic($topicObj);
    next unless $cats;

    $foundTopics++;
    writeDebug("$foundTopics: reading $topicName ... cats=@$cats");
    my %facets = ();
    foreach my $catName (@$cats) {
      my $cat = $hierarchy->getCategory($catName);
      unless ($cat) {
	throw Error::Simple("topic $topicName has got an unknown category $catName");
      }
      my $foundFacet = 0;
      foreach my $facet (keys %map) {
	if ($map{$facet}->subsumes($cat)) {
	  push @{$facets{$facet}}, $catName;
	  $foundFacet = 1;
	  last;
	}
      }
      throw("oops, $catName not mapped onto any facet")
       	unless $foundFacet;
    }
  
    my ($meta, $text) = Foswiki::Func::readTopic($theWeb, $topicName);
    #writeDebug("OLD meta:\n".$meta->stringify());
    
    if (%facets) {
      if ($debug) {
	my $message = '';
	foreach my $facet (sort keys %facets) {
	  $message .= "\n  $facet=".join(', ', @{$facets{$facet}});
	}
	writeDebug("$topicName facets: $message");
      }

      foreach my $facet (sort keys %facets) {
	$meta->putKeyed('FIELD', {
	  name => $facet,
	  title => $facet,
          value => join(', ', @{$facets{$facet}}),
	});
      }
    }
    if ($theInTopicType ne $theOutTopicType) {
      $meta->putKeyed('FIELD', {
	name => 'TopicType',
	title => 'TopicType',
	value => $theOutTopicType,
      });
    }
    if (defined $theNewForm) {
      my $formDef = $meta->get('FORM');
      $formDef->{name} = $theNewForm;
    }
    #writeDebug("NEW meta:\n".$meta->stringify());

    Foswiki::Func::saveTopic($theWeb, $topicName, $meta, $text);
  }

  return "OK: converted $foundTopics topics\n";
}

##############################################################################
sub returnRESTResult {
  my ($response, $status, $text) = @_;

  $response->header(
    -status  => $status,
    -type    => 'text/html',
  );

  $response->print($text);
  writeDebug($text) if $status >= 400;
}

1;
