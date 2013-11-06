# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2007-2013 Michael Daum http://michaeldaumconsulting.com
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
# 
# As per the GPL, removal of this notice is prohibited.

package Foswiki::Form::Cat;
use Foswiki::Form::FieldDefinition ();
our @ISA = ('Foswiki::Form::FieldDefinition');

use Foswiki::Plugins::ClassificationPlugin ();
use Foswiki::Func ();
use strict;

sub new {
    my $class = shift;
    my $this = $class->SUPER::new( @_ );

    return $this;
}

sub finish {
    my $this = shift;
    $this->SUPER::finish();
    undef $this->{_options};
}

sub isMultiValued { 
  return 1;
}

sub getOptions { # needed by FieldDefinition
  my $this = shift;

  my $query = Foswiki::Func::getCgiQuery();

  # trick this in by getting all values from the query
  # and allow them to be asserted
  my @values = ();
  my @valuesFromQuery = $query->param($this->{name});
  foreach my $item (@valuesFromQuery) {
    next unless defined $item;
    foreach my $value (split(/\s*,\s*/, $item)) {
      push @values, $value if $value;
    }
  }

  return \@values;
}

sub renderForDisplay {
    my ( $this, $format, $value, $attrs, $web, $topic ) = @_;
    # SMELL: working around the topicObj not being added to the renderForDisplay API as it does for
    # renderForEdit, by using some extra params ... *shudder*

    if ( !$attrs->{showhidden} ) {
        my $fa = $this->{attributes} || '';
        if ( $fa =~ /H/ ) {
            return '';
        }
    }

    $web ||= $this->{session}->{webName};

    my $hierarchy = Foswiki::Plugins::ClassificationPlugin::getHierarchy($web);

    my @value = ();
    foreach my $catName (split(/\s*,\s*/, $value)) {
      my $cat = $hierarchy->getCategory($catName);
      if (defined $cat) {
        push @value, $cat->getLink();
      } else {
        push @value, $catName;
      }
    }
    $value = join(', ', @value);

    return $this->SUPER::renderForDisplay($format, $value, $attrs);
}

sub renderForEdit {
  my $this = shift;

  # get args in a backwards compatible manor:
  my $metaOrWeb = shift;

  my $meta;
  my $web;
  my $topic;

  if (ref($metaOrWeb)) {
    # new: $this, $meta, $value
    $meta = $metaOrWeb;
    $web = $meta->web;
    $topic = $meta->topic;
  } else {
    # old: $this, $web, $topic, $value
    $web = $metaOrWeb;
    $topic = shift;
    ($meta, undef) = Foswiki::Func::readTopic($web, $topic);
  }

  my $value = shift;
  $value =~ s/\s*\w+=\".*?\"\s*//g; # remove top="..."

  # SMELL find a condition under which we render hidden instead
  #my $query = Foswiki::Func::getCgiQuery();
  #my $form = $query->param('form');
  #return ('', '<noautolink>'.$this->renderHidden($meta).'</noautolink>')
  #  unless $form;

  my %params = Foswiki::Func::extractParameters($this->{value});
  my $top = $params{top} || 'TopCategory';

  $web = $params{web} if defined $params{web};
  my $baseWeb = $this->{session}->{webName};

  Foswiki::Func::readTemplate("classificationplugin");

  my $widget = Foswiki::Func::expandTemplate("categoryeditor");
  $widget =~ s/\$baseweb/$baseWeb/g;
  $widget =~ s/\$web/$web/g;
  $widget =~ s/\$topic/$topic/g;
  $widget =~ s/\$top/$top/g;
  $widget =~ s/\$value/$value/g;
  $widget =~ s/\$name/$this->{name}/g;
  $widget =~ s/\$title/$this->{title}/g;
  $widget =~ s/\$type/$this->{type}/g;
  $widget =~ s/\$size/$this->{size}/g;
  $widget =~ s/\$attrs/$this->{attributes}/g;
  $widget =~ s/\$(name|type|size|value|attrs)//g;

  #print STDERR "widget=$widget\n";

  return ('', Foswiki::Func::expandCommonVariables($widget, $topic, $web));
}

1;
