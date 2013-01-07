# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2013 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::ClassificationPlugin::Category;

use strict;
use Foswiki::Contrib::DBCacheContrib::Search ();
use Foswiki::Plugins::DBCachePlugin::Core ();

use constant DEBUG => 0; # toggle me

###############################################################################
# static
sub writeDebug {
  #Foswiki::Func::writeDebug('- ClassificationPlugin - '.$_[0]) if DEBUG;
  return unless DEBUG;
  use Foswiki::Time ();
  my $timeStamp = Foswiki::Time::formatTime(time(), '$hour:$min:$sec');
  print STDERR $timeStamp.' - ClassificationPlugin::Category - '.$_[0]."\n";
}

################################################################################
# constructor
sub new {
  my $class = shift;
  my $hierarchy = shift;
  my $name = shift;

  my $this = {
    name=>$name,
    origWeb=>$hierarchy->{web},
    id=>$hierarchy->{idCounter}++,
    hierarchy=>$hierarchy,
    summary=>'',
    title=>$name,
    order=>99999999,
    @_
  };
  $this->{gotUpdate} = 1;

  $this = bless($this, $class);

  # register to hierarchy
  $hierarchy->setCategory($name, $this);

  #writeDebug("new category name=$this->{name} title=$this->{title} web=$hierarchy->{web}"); 

  return $this;
}

###############################################################################
sub purgeCache {
  my $this = shift;

  #writeDebug("purging category cache for $this->{name}");
  undef $this->{_topics};
  undef $this->{_tags};
  undef $this->{_prefs};
  undef $this->{_subsumes};
  undef $this->{_contains};
  undef $this->{_nrLeafs};
  undef $this->{_isCyclic};
  undef $this->{_perms};


  $this->{gotUpdate} = 1;
}

###############################################################################
# destructor
sub DESTROY {
  my $this = shift;

  undef $this->{icon};
  undef $this->{parents};
  undef $this->{allparents};
  undef $this->{children};
  undef $this->{hierarchy};
}

###############################################################################
sub init {
  my $this = shift;

  #writeDebug("init category $this->{name} in web $this->{hierarchy}->{web}");
  foreach my $name (keys %{$this->{parents}}) {
    my $parent = $this->{parents}{$name};

    # make sure the parents are pointers, not the category names
    unless (ref($parent)) {
      $parent = $this->{hierarchy}->getCategory($name);
      if ($parent) {
        $this->{parents}{$name} = $parent;
      } else {
        delete $this->{parents}{$name};
      }
    }

    # establish child relation
    $parent->addChild($this) if $parent;
  }

  $this->{gotUpdate} = 1;
}

###############################################################################
sub getLeafs {
  my ($this, $result, $seen) = @_;

  $seen ||= {};
  $result ||= {};

  return keys %$result if $seen->{$this};
  $seen->{$this} = 1;

#  foreach my $topic ($this->getTopics()) {
#    $result->{$topic} = 1;
#  }

  my $foundChild = 0;
  foreach my $child ($this->getChildren()) {
    next if $child->{name} eq 'BottomCategory';
    $foundChild = 1;
    $child->getLeafs($result, $seen);
  }
  
  unless($foundChild) {
    $result->{$this->{name}} = 1;
    #writeDebug("found leaf $this->{name}");
  }

  return keys %$result;
}

###############################################################################
sub countLeafs {
  my ($this, $filter) = @_;
	
  $filter ||= '';
  my $nrLeafs = $this->{_nrLeafs}{$filter};

  unless (defined $nrLeafs) {
    #writeDebug("counting leafs of $this->{name}, filter=$filter");

    my @leafs = $this->getLeafs();
    if ($filter) {
      my $db = Foswiki::Plugins::DBCachePlugin::Core::getDB($this->{hierarchy}->{web});
      my $search= new Foswiki::Contrib::DBCacheContrib::Search($filter);
      $nrLeafs = 0;
      foreach my $topicName (@leafs) {
        my $topicObj = $db->fastget($topicName);
        next if $search->matches($topicObj);
        $nrLeafs++;
      }
    } else {
      $nrLeafs = scalar(@leafs);
    }
    $nrLeafs--;
    $nrLeafs = 0 unless $nrLeafs > 0;

    $this->{_nrLeafs}{$filter} = $nrLeafs;
    $this->{gotUpdate} = 1;
    #writeDebug("countLeafs($this->{name})=$nrLeafs");
  }

  return $nrLeafs;
}

###############################################################################
# recursive version of the Wallace-Kollias for transitive closure
sub computeDistance {
  my ($this, $distance, $ancestors) = @_;

  my $thisId = $this->{id};
  return if $ancestors->{$thisId};


  # become an ancestor
  $ancestors->{$thisId} = $this;
  $$distance[$thisId][$thisId] = 0;
      
  # loop over all ancestors
  foreach my $ancestor (values %$ancestors) {
    next unless $ancestor;
    my $ancestorId = $ancestor->{id};
    my $newDistance = $$distance[$ancestorId][$thisId] + 1;

    # loop over all children
    foreach my $child ($this->getChildren()) {
      my $childId = $child->{id};
      my $ancestorToChild = $$distance[$ancestorId][$childId];

      # ... to find out if there is a shorter path
      if (!$ancestorToChild || $newDistance < $ancestorToChild) {
        $$distance[$ancestorId][$childId] = $newDistance;
        #writeDebug("computed distance ($ancestor->{name},$child->{name})=$newDistance");
      }
    }
  }

  # recursion
  foreach my $child ($this->getChildren()) {
    $child->computeDistance($distance, $ancestors);
  }

  $ancestors->{$thisId} = 0;
}

###############################################################################
sub distance {
  my ($this, $that) = @_;

  return $this->{hierarchy}->catDistance($this, $that);
}

###############################################################################
sub subsumes {
  my ($this, $that) = @_;

  return $this->{hierarchy}->subsumes($this, $that);
}

###############################################################################
# returns 1 if the given topic is in the current category or any sub-category
sub contains {
  my ($this, $topic) = @_;

  return 1 if $this->{name} eq 'TopCategory';
  return 0 if $this->{name} eq 'BottomCategory';

  my $result = $this->{_contains}{$topic};
  return $result if defined $result;

  $result = 0;
  my $hierarchy = $this->{hierarchy};
  my $cat = $hierarchy->getCategory($topic);
  return 0 if $cat;  
  my $cats = $hierarchy->getCategoriesOfTopic($topic);
  if ($cats) {
    foreach my $cat (@$cats) {
      #writeDebug("checking $cat");
      $result = $hierarchy->subsumes($this, $cat);
      last if $result;
    }
  }
  #writeDebug("called contains($this->{name}, $topic) = $result");
  
  # cache
  $this->{_contains}{$topic} = $result;
  $this->{gotUpdate} = 1;
  return $result;
}

###############################################################################
sub setParents {
  my $this = shift;

  #writeDebug("called $this->{name}->setParents(@_)");
  foreach my $parent (@_) {
    my $parentObj = $parent;
    my $parentName = $parent;
    if(ref($parentObj)) {
      $parentName = $parentObj->{name};
    } else {
      $parentObj = $this->{hierarchy}->getCategory($parent) || 1;
    }
    $this->{parents}{$parentName} = $parentObj;
  }
  $this->{gotUpdate} = 1;
}

###############################################################################
# get all parent nodes
# subdsumes may be a category or category name to restrict parents to those
# being subsumed
sub getParents {
  my ($this, $subsumes) = @_;

  my $subsumesCat;
  if (!$subsumes && ref($subsumes)) {
    $subsumesCat = $subsumes;
  } else {
    $subsumesCat = $this->{hierarchy}->getCategory($subsumes);
  }

  return values %{$this->{parents}} unless $subsumesCat;

  my @parents = ();
  foreach my $parent (values %{$this->{parents}}) {
    push @parents, $parent if $subsumesCat->subsumes($parent);
  }

  return @parents;
}


###############################################################################
sub getAllParents {
  my $this = shift;

  return keys %{$this->_getAllParents()};
}

###############################################################################
sub _getAllParents {
  my ($this, $seen) = @_;

  return {} if $this eq $this->{hierarchy}{_top};
  $seen ||= {};

  if (!defined ($this->{allparents}) && !$seen->{$this->{name}}) {

    $seen->{$this->{name}} = 1;
    $this->{allparents} = {};
    
    my @parents = $this->getParents();
    foreach my $parent (@parents) {
      $this->{allparents}{$parent->{name}} = 1 unless $parent eq $this->{hierarchy}{_top};
      $this->{allparents} = {%{$this->{allparents}}, %{$parent->_getAllParents($parent, $seen)}};
    }
    $this->{gotUpate} = 1;
  }

  return $this->{allparents};
}

###############################################################################
sub countTopics {
  my ($this, $filter) = @_;

  my $topics = $this->getAllTopics();
  my @topics = keys %$topics;

  @topics = $this->filterTopics(\@topics, $filter) if $filter;

  return scalar(@topics);;
}

###############################################################################
sub getAllTopics {
  my ($this, $seen) = @_;

  $seen ||= {};

  return {} if $seen->{$this->{name}};
  $seen->{$this->{name}} = 1;

  $this->getTopics();
  my %topics = %{$this->{_topics}};

  foreach my $child ($this->getChildren()) {
    next if $child->{name} eq 'BottomCategory';
    %topics = (%topics, %{$child->getAllTopics($seen)});
  }

  return \%topics;
}

###############################################################################
sub getTopics {
  my ($this, $filter) = @_;

  unless (defined($this->{_topics})) {
    writeDebug("refreshing _topics in $this->{name}");

    my $hierarchy = $this->{hierarchy};
    my $db = Foswiki::Plugins::DBCachePlugin::Core::getDB($hierarchy->{web});

    foreach my $topicName ($db->getKeys()) {
      my $topicObj = $db->fastget($topicName);

      my $form = $topicObj->fastget("form");
      next unless $form;

      $form = $topicObj->fastget($form);
      next unless $form;

      my $topicTypes = $form->fastget('TopicType');
      next unless $topicTypes;

      next if $topicTypes =~ /\bCategory\b/o;

      my $cats = $hierarchy->getCategoriesOfTopic($topicObj);
      next unless $cats;

      foreach my $name (@$cats) {
        next unless $name eq $this->{name};
        writeDebug("adding $topicName it to category $this->{name}");
        $this->{_topics}{$topicName} = 1;
	$this->{gotUpdate} = 1;
      }
    }
  } else {
    writeDebug("_topics found in cache of $this->{name}");
  }

  my @topics = keys %{$this->{_topics}};
  return @topics unless $filter;
  return $this->filterTopics(\@topics, $filter);
}

###############################################################################
sub filterTopics {
  my ($this, $topics, $filter) = @_;

  return @$topics unless $filter && @$topics;

  my $hierarchy = $this->{hierarchy};
  my $db = Foswiki::Plugins::DBCachePlugin::Core::getDB($hierarchy->{web});
  my $search = new Foswiki::Contrib::DBCacheContrib::Search($filter);

  return grep {
    my $topicObj = $db->fastget($_);
    $topicObj && $search->matches($topicObj);
  } @$topics;
}

###############################################################################
sub getTagsOfTopics {
  my $this = shift;

  unless (defined($this->{_tags})) {
    #writeDebug("gathering tags in category $this->{name}");
    my %tags;
    my $hierarchy = $this->{hierarchy};
    my $db = Foswiki::Plugins::DBCachePlugin::Core::getDB($hierarchy->{web});
    foreach my $topic ($this->getTopics()) {
      my $topicObj = $db->fastget($topic);
      next unless $topicObj;
      my $form = $topicObj->fastget("form");
      next unless $form;
      $form = $topicObj->fastget($form);
      next unless $form;
      my $tags = $form->fastget('Tag');
      next unless $tags;
      foreach my $tag (split(/\s*,\s*/, $tags)) {
        $tags{$tag}++;
      }
    }
    %{$this->{_tags}} = %tags;
  }

  return keys %{$this->{_tags}};
}

###############################################################################
# register a subcategory
sub addChild {
  my ($this, $category) = @_;

  #writeDebug("called $this->{name}->addChild($category->{name})");
  $this->{children}{$category->{name}} = $category;
  $this->{gotUpdate} = 1;
}

###############################################################################
sub getChildren {
  return values %{$_[0]->{children}};
}

###############################################################################
sub setOrder {
  my ($this, $order) = @_;
  $this->{order} = $order;
  $this->{gotUpdate} = 1;
  return $order;
}

###############################################################################
sub setSummary {
  my ($this, $summary) = @_;
  $summary = urlDecode($summary);
  $this->{summary} = $summary;
  $this->{gotUpdate} = 1;
  return $summary;
}

###############################################################################
sub setTitle {
  my ($this, $title) = @_;
  $title = urlDecode($title);
  $this->{title} = $title;
  $this->{gotUpdate} = 1;
  return $title;
}

###############################################################################
sub isCyclic {
  my $this = shift;

  my $result = $this->{_isCyclic};
  return $result if defined $result;

  #writeDebug("called isCyclic($this->{name})");

  $result = 0;
  foreach my $child ($this->getChildren()) {
    next if $child->{name} eq 'BottomCategory';
    $result = $child->subsumes($this);
    if ($result) {
      #writeDebug("child $child->{name} subsumes $this->{name}: $result");
      last;
    }
  }
  
  # cache
  $this->{_isCyclic} = $result;
  $this->{gotUpdate} = 1;
  return $result;
}

###############################################################################
sub checkAccessPermission {
  my ($this, $user, $type, $seen) = @_;

  return 1 if $this->{name} =~ /^(TopCategory|BottomCategory)$/;

  $type ||= 'VIEW';
  $seen ||= {};

  # prevent infinit recursions
  return 0 if $seen->{$this};
  $seen->{$this} = 1;

  # normalize calling parameter not to trash the cache
  $user = Foswiki::Func::getWikiName($user);

  # lookup cache
  my $access = $this->{_perms}{$type}{$user};

  unless (defined $access) {
    my $topic = $this->{name};
    my $web = $this->{origWeb};
    #writeDebug("checking $type access to category $web.$topic for $user");
    $access = Foswiki::Func::checkAccessPermission($type, $user, undef, $topic, $web);
  
    if ($access) {
      # recurse til access granted
      foreach my $parent (values %{$this->{parents}}) {
        next if $parent->{name} eq 'TopCategory';
        $access = $parent->checkAccessPermission($user, $type, $seen);
        last if $access;
      }
    }

    # cache result
    $this->{_perms}{$type}{$user} = $access;
  }

  return $access;
}

###############################################################################
sub getPreferences {
  my ($this) = @_;

  unless ($this->{_prefs}) {
    require Foswiki::Prefs::PrefsCache;
    $this->{_prefs} = new Foswiki::Prefs::PrefsCache($this->{hierarchy}->{_prefs}, undef, 'CAT', 
      $this->{origWeb}, $this->{name}); 
  }
  
  return $this->{_prefs};
}

###############################################################################
sub importCategories {
  my ($this, $impCats, $seen) = @_;

  return unless $impCats;
  $seen ||= {};

  #writeDebug("already seen=".join(',', sort keys %$seen));

  my $thisHierarchy = $this->{hierarchy};
  my $thisWeb = $thisHierarchy->{web};
  foreach my $impCat (split(/\s*,\s*/, $impCats)) {

    my ($impWeb, $impTopic) = Foswiki::Func::normalizeWebTopicName($thisWeb, $impCat);
    $impWeb =~ s/\//\./go;
    next unless Foswiki::Func::webExists($impWeb);

    # prevent deep recursion importing from the same web
    next if $thisWeb eq $impWeb;

    # SMELL: prevent deep recursion of two webs importing each other's categories
    my $impHierarchy = Foswiki::Plugins::ClassificationPlugin::getHierarchy($impWeb);
    next unless $impHierarchy;

    $impCat = $impHierarchy->getCategory($impTopic);
    next unless $impCat;

    #writeDebug("importing category $impTopic from $impWeb");
    
    # import all child categories of impCat
    foreach my $impChild ($impCat->getChildren()) {
      my $name = $impChild->{name};
      next if $name eq 'BottomCategory';
      next if $seen->{$name};
      $seen->{$name} = 1;
      next if Foswiki::Func::topicExists($thisWeb, $name);

      my %parents = map {$_->{name}=>1} $impChild->getParents();
      $parents{$this->{name}} = 1;

      my $cat = $thisHierarchy->getCategory($name);
      $cat = $thisHierarchy->createCategory($name);
      $cat->setTitle($impChild->{title});
      $cat->setSummary($impChild->{summary});
      $cat->setOrder($impChild->{order});
      $cat->setParents(keys %parents);
      $cat->setIcon($impChild->getIcon());
      $cat->{origWeb} = $impWeb;

      # recurse
      $cat->importCategories("$impWeb.$name", $seen);
    }
  }

  $this->{gotUpdate} = 1;
}

###############################################################################
sub setIcon {
  my ($this, $icon) = @_;

  $this->{icon} = $icon;
  $this->{gotUpdate} = 1;
  return $icon;
}

###############################################################################
sub getIcon {
  my $this = shift;

  return $this->{icon} || 'folder.gif';
}

###############################################################################
sub getIconUrl {
  my $this = shift;

  my $icon = $this->{icon} || 'folder.gif';

  my $pubUrlPath = $Foswiki::cfg{PubUrlPath};

  return 
    $pubUrlPath.
    '/Applications/ClassificationApp/IconSet/'.
    $icon;

}

###############################################################################
sub getLink {
  my $this = shift;

  return "<a href='".$this->getUrl()."' rel='tag' class='$this->{name}'><noautolink>$this->{title}</noautolink></a>";
}

###############################################################################
sub getUrl {
  my $this = shift;
  
  my $hierWeb = $this->{hierarchy}->{web};
  if ($hierWeb ne $this->{origWeb}) {
    return Foswiki::Func::getScriptUrl($hierWeb, 
      'TopCategory', 'view', catname=>$this->{name});
  }

  return Foswiki::Func::getScriptUrl($hierWeb, 
      $this->{name}, 'view');
}

###############################################################################
# get a list of all offsprings
sub getSubCategories {
  my ($this, $minDepth, $maxDepth) = @_;

  my %result = ();
  $minDepth ||= 1;
  $maxDepth ||= 99999999;
  $this->_getSubCategories($minDepth, $maxDepth, \%result);
  return values %result;
}

sub _getSubCategories {
  my ($this, $minDepth, $maxDepth, $result) = @_;

  return if $maxDepth <= 0;

  my $botCat = $this->{hierarchy}->{_bottom};
  foreach my $child ($this->getChildren()) {
    next if $child eq $botCat;
    next if $result->{$child->{name}};

    $result->{$child->{name}} = $child if $minDepth <= 1;
    $child->_getSubCategories($minDepth-1, $maxDepth-1, $result);
  }
}


###############################################################################
sub traverse {
  my ($this, $params, $nrCalls, $index, $nrSiblings, $seen, $depth, $parentTitle) = @_;

  $depth ||= 0;

  my $maxDepth = $params->{depth};
  return '' if $maxDepth && $depth >= $maxDepth;

  $index ||= 1;
  $nrSiblings ||= 1;
  $seen ||= {};
  return '' if $seen->{$this};
  $seen->{$this} = 1;

  #return '' unless $this->checkAccessPermission();
  $$nrCalls++;

  my $header = $params->{header} || '';
  my $footer = $params->{footer} || '';
  my $format = $params->{format};
  my $separator = $params->{separator} || '';

  # use topformat if we render the top category and there's only one sibling
  if ($nrSiblings == 1) {
    $format = $params->{topformat} if defined $params->{topformat};
  }

  my $matchAttr = $params->{matchattr} || 'name';
  $matchAttr = 'name' unless $matchAttr =~ /^(name|title)$/;
  my $matchCase = $params->{matchcase} || 'on';

  $format = '<ul><li> <a href="$url"><img src="$icon" />$title</a> ($leafs) $children</li></ul>' 
    unless defined $format;

  # get sub-categories
  my @children = 
    sort {
      $a->{order} <=> $b->{order} ||
      $a->{title} cmp $b->{title}
    } map {
      $this->{children}{$_}
    } grep {!/^BottomCategory$/} keys %{$this->{children}};
  my $nrChildren = scalar(@children);

  #writeDebug("traverse() nrCalls=$$nrCalls, depth=$depth, name=$this->{name} order=$this->{order}");
  #writeDebug("children=".join(', ', map {$_->{name}} @children));

  my $doChildren = (@children)?1:0;
  my $isExpanded = 0; # set to true if this category is opened by a subsumed opener
  my $isOpener = 0;
  if ($params->{open}) {
    $doChildren = 0;
    my %openers = ();
    if (defined $params->{_openers}) {
      %openers = %{$params->{_openers}};
    } else {
      my $openers = Foswiki::Plugins::ClassificationPlugin::Core::expandVariables($params->{open},
        'web'=>$this->{hierarchy}->{web}, 
        'origweb'=>$this->{origWeb} || '', 
        'topic'=>$this->{name},
        'name'=>$this->{name},
        'summary'=>$this->{summary},
        'title'=>$this->{title},
        'order'=>$this->{order},
      );
      $openers = Foswiki::Func::expandCommonVariables($openers);
      my $isCacheable = ($params->{open} eq $openers)?1:0;
      $openers =~ s/^\s*(.*?)\s*$/$1/;
      #writeDebug("openers=$openers");
      %openers = map {$_ => 1} split(/\s*,\s*/, $openers);
      $params->{_openers} = \%openers if $isCacheable;
    }
    $isOpener = ($openers{$this->{name}})?1:0;
    foreach my $opener (keys %openers) {
      #writeDebug("checking at $this->{name} opener '$opener'");
      my $distance = $this->distance($opener);
      #if ($this->subsumes($opener)) {
      # open thos that show up within the given depth
      if (defined $distance && $distance >= 0 && (!$maxDepth || $distance <= $maxDepth)) {
        #writeDebug("$this->{name} opened by $opener");
        $doChildren = 1;
        $isExpanded = 1;
        last;
      }
    }
  }

  #print STDERR "$this->{name}: isOpener=$isOpener, isExpanded=$isExpanded, doChildren=$doChildren\n";

  if (!$isOpener && !$isExpanded && $params->{hideclosed} && $params->{hideclosed} eq 'on') {
    #writeDebug("hideclosed $this->{name} / $this->{title}");
    return '';
  }


  my @subResult;
  my $childIndex = 1;
  if ($doChildren) {
    #writeDebug("doing children of $this->{name}/$this->{title}");
    foreach my $child (@children) {
      next if $child->{name} eq 'BottomCategory';
      my $childResult = $child->traverse($params, $nrCalls, $childIndex, $nrChildren, $seen, $isExpanded?$depth:$depth+1, $this->{title});
      push @subResult, $childResult if $childResult;
      $childIndex++;
    }
  } else {
    #writeDebug("not decending at $this->{name}");
    if (@children) {
      my $placeholder = $params->{placeholder};
      push @subResult, $placeholder if $placeholder;
    }
  }

  my $subResult = '';
  if (@subResult) {
    $separator = Foswiki::Plugins::ClassificationPlugin::Core::expandVariables($separator);
    $subResult = join($separator, @subResult);
  }

  my $unique = $params->{unique} || 'off';
  $seen->{$this} = 0 unless $unique eq 'on';

  my $minDepth = $params->{mindepth};

  return $subResult 
    if $minDepth && $depth <= $minDepth;

  if ($matchCase eq 'on') {
    return $subResult
      if defined $params->{exclude} && $this->{$matchAttr} =~ /^($params->{exclude})$/;
    return $subResult
      if defined $params->{include} && $this->{$matchAttr} !~ /^($params->{include})$/;
  } else {
    return $subResult
      if defined $params->{exclude} && $this->{$matchAttr} =~ /^($params->{exclude})$/i;
    return $subResult
      if defined $params->{include} && $this->{$matchAttr} !~ /^($params->{include})$/i;
  }

  my $filter = $params->{filter};
  my $nrTopics;

  if ($header =~ /\$count/ ||
      $footer =~ /\$count/ ||
      $format =~ /\$count/ ||
      (defined $params->{hidenull} && $params->{hidenull} eq 'on')) {

    if ($params->{nrtopics}) {
      unless ($params->{_nrTopics}) {
        my %nrTopics = ();
        foreach my $item (split(/\s*,\s*/, $params->{nrtopics})) {
          if ($item =~ /^(.*):(.*)$/) {
            $nrTopics{$1} = $2;
          }
        }
        $params->{_nrTopics} = \%nrTopics;
      }
      $nrTopics = $params->{_nrTopics}{$this->{name}} || 0;
    } else {
      $nrTopics = $this->countTopics($filter);
    }
  }

  return $subResult
    if defined $params->{hidenull} && $params->{hidenull} eq 'on' && !$nrTopics;

  my $nrLeafs;

  if ($header =~ /\$leafs/ ||
      $footer =~ /\$leafs/ ||
      $format =~ /\$leafs/) {

    if ($params->{nrleafs}) {
      unless ($params->{_nrLeafs}) {
        my %nrLeafs = ();
        foreach my $item (split(/\s*,\s*/, $params->{nrleafs})) {
          if ($item =~ /^(.*):(.*)$/) {
            $nrLeafs{$1} = $2;
          }
        }
        $params->{_nrLeafs} = \%nrLeafs;
      }
      $nrLeafs = $params->{_nrLeafs}{$this->{name}} || 0;
    } else {
      $nrLeafs = $this->countLeafs($filter);
    }
  }

  return $subResult
    if defined $params->{duplicates} && $params->{duplicates} eq 'off' && $params->{seen}{$this->{name}};

  # DEPRECATED: use filter instead
  my $tagFilter = $params->{tags};
  if ($tagFilter) {
    #writeDebug("tagFilter=$tagFilter");
    $this->getTagsOfTopics(); # CAUTION: depends on filter
    foreach my $tag (split(/\s*,\s*/, $tagFilter)) {
      return $subResult unless defined $this->{_tags}{$tag};
    }
  }

  $params->{seen}{$this->{name}} = 1;

  my $isCyclic = 0;
  $isCyclic = $this->isCyclic() if $format =~ /\$cyclic/;

  my $indent = $params->{indent} || '   ';
  $indent = $indent x $depth;

  my $iconUrl = $this->getIconUrl();

  my $tags = '';
  if ($header =~ /\$tags/ ||
      $footer =~ /\$tags/ ||
      $format =~ /\$tags/) {
    #writeDebug("getting tags");
    my @tags = $this->getTagsOfTopics(); # CAUTION: depends on filter
    $tags = join(', ', @tags);
  }

  my $parents = '';
  if ($header =~ /\$parents/ ||
      $footer =~ /\$parents/ ||
      $format =~ /\$parents/) {
    $parents = join(', ', map {$_->{name}} $this->getParents());
  }

  my $distToRoot = 0;
  if ($header =~ /\$depth/ ||
      $footer =~ /\$depth/ ||
      $format =~ /\$depth/) {
    $distToRoot = abs($this->distance($this->{hierarchy}{_top}));
  }

  my $breadCrumbs = '';
  if ($header =~ /\$breadcrumbs/ ||
      $footer =~ /\$breadcrumbs/ ||
      $format =~ /\$breadcrumbs/) {
    my @breadCrumbs = ();
    my %seen = ();
    my $parent = $this;
    while ($parent) {
      last if $seen{$parent->{name}};
      $seen{$parent->{name}} = 1;
      push @breadCrumbs, $parent->{name};
      my @parents = $parent->getParents();
      last unless @parents;
      $parent = shift @parents;
      last if !$parent || $parent eq $parent->{hierarchy}{_top};
    }
    $breadCrumbs = join(', ', reverse @breadCrumbs);
  }

  my $truncTitle = $this->{title};
  $truncTitle =~ s/^$parentTitle\b\s*// if $parentTitle;

  if ($subResult) {
    $header = Foswiki::Plugins::ClassificationPlugin::Core::expandVariables($header,
      'web'=>$this->{hierarchy}->{web}, 
      'origweb'=>$this->{origWeb} || '', 
      'topic'=>$this->{name},
      'name'=>$this->{name},
      'summary'=>$this->{summary},
      'title'=>$this->{title},
      'trunctitle'=>$truncTitle,
      'siblings'=>$nrSiblings,
      'count'=>$nrTopics,
      'index'=>$index,
      'subcats'=>$nrChildren,
      'call'=>$$nrCalls,
      'leafs'=>$nrLeafs,
      'cyclic'=>$isCyclic,
      'id'=>$this->{id},
      'depth'=>$distToRoot,
      'indent'=>$indent,
      'icon'=>$iconUrl,
      'tags'=>$tags,
      'parents'=>$parents,
      'breadcrumbs'=>$breadCrumbs,
      'order'=>$this->{order},
      'isexpanded'=>$isExpanded?'true':'false',
    );
    $footer = Foswiki::Plugins::ClassificationPlugin::Core::expandVariables($footer,
      'web'=>$this->{hierarchy}->{web}, 
      'origweb'=>$this->{origWeb} || '', 
      'topic'=>$this->{name},
      'name'=>$this->{name},
      'summary'=>$this->{summary},
      'title'=>$this->{title},
      'trunctitle'=>$truncTitle,
      'siblings'=>$nrSiblings,
      'count'=>$nrTopics,
      'index'=>$index,
      'subcats'=>$nrChildren,
      'call'=>$$nrCalls,
      'leafs'=>$nrLeafs,
      'cyclic'=>$isCyclic,
      'id'=>$this->{id},
      'depth'=>$distToRoot,
      'indent'=>$indent,
      'icon'=>$iconUrl,
      'tags'=>$tags,
      'parents'=>$parents,
      'breadcrumbs'=>$breadCrumbs,
      'order'=>$this->{order},
      'isexpanded'=>$isExpanded?'true':'false',
    );
    $subResult = $header.$subResult.$footer;
  }

  return Foswiki::Plugins::ClassificationPlugin::Core::expandVariables($format, 
    'link'=>($this->{name} =~ /^(TopCategory|BottomCategory)$/)?
      "<b>$this->{title}</b>":$this->getLink(),
    'url'=>($this->{name} =~ /^(TopCategory|BottomCategory)$/)?"":
      $this->getUrl(),
    'web'=>$this->{hierarchy}->{web}, 
    'origweb'=>$this->{origWeb} || '', 
    'topic'=>$this->{name},
    'name'=>$this->{name},
    'summary'=>$this->{summary},
    'title'=>$this->{title},
    'trunctitle'=>$truncTitle,
    'children'=>$subResult,
    'siblings'=>$nrSiblings,
    'count'=>$nrTopics,
    'index'=>$index,
    'subcats'=>$nrChildren,
    'call'=>$$nrCalls,
    'leafs'=>$nrLeafs,
    'cyclic'=>$isCyclic,
    'id'=>$this->{id},
    'depth'=>$distToRoot,
    'indent'=>$indent,
    'icon'=>$iconUrl,
    'tags'=>$tags,
    'parents'=>$parents,
    'breadcrumbs'=>$breadCrumbs,
    'order'=>$this->{order},
    'isexpanded'=>$isExpanded?'true':'false',
  );
}

###############################################################################
# from Foswiki.pm
sub urlDecode {
    my $text = shift;

    $text =~ s/%([\da-f]{2})/chr(hex($1))/gei;

    return $text;
}

1;
