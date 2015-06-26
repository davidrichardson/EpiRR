#!/usr/bin/env perl
# Copyright 2014 European Molecular Biology Laboratory - European Bioinformatics Institute
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
use strict;
use warnings;
use Mojolicious::Lite;
use Carp;

use EpiRR::Schema;
use EpiRR::Service::OutputService;
use EpiRR::App::Controller;

plugin 'Config';

my $db = app->config('db');

my $schema = EpiRR::Schema->connect( $db->{dsn}, $db->{user}, $db->{password}, )
  || die "Could not connect";

my $os = EpiRR::Service::OutputService->new( schema => $schema );
my $controller =
  EpiRR::App::Controller->new( output_service => $os, schema => $schema );

get '/view/all' => sub {
    my $self = shift;

    my $datasets = $controller->fetch_current();

    $self->respond_to(
        json => sub {          
            my @hash_datasets;
            for my $d (@$datasets) {
                my $url = $self->req->url->to_abs;
                my $path = $url->path;
                my $hd = $d->to_hash;
                my $full_accession = $d->full_accession;

                my $link_path = $path;
                $link_path =~ s!/view/all!/view/$full_accession!;
                $link_path =~ s/\.json$//;
                
                $url->path($link_path);
                
                $hd->{_links}{self} = "$url";
                push @hash_datasets, $hd;
            }

            $self->render( json => \@hash_datasets );
        },
        html => sub {
            $self->stash( datasets => $datasets );
            $self->render( template => 'viewall' );
        },
    );

};

get '/view/#id' => sub {
    my $self    = shift;
    my $id      = $self->param('id');
    my $dataset = $controller->fetch($id);

    if ( !$dataset ) {
        $self->reply->not_found;
        return;
    }
    $self->respond_to(
        json => { json => $dataset },
        html => sub {
            $self->stash( dataset => $dataset );
            $self->render( template => 'viewid' );
        },
    );
};

get '/' => sub {
  my $self = shift;
  $self->render(template =>  'index');
};

# Start the Mojolicious command system
app->start;

__DATA__

@@ index.html.ep
<!DOCTYPE html>
<html>
<head>
<title>EpiRR Endpoints</title>
<link href="../favicon.ico" rel="icon" type="image/x-icon" />
<!-- Latest compiled and minified CSS -->
<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap.min.css">
<!-- Optional theme -->
<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap-theme.min.css">
</head>
<body>
<div class="container-fluid">
<h1>EpiRR REST API</h1>
<h2>Endpoints</h2>
<dl class="dl-horizontal">
<dt>/view/:id</dt>
<dd>View the detail of one reference dataset</dt>
<dt>/view/all</dt>
<dd>List all current datasets</dt>
</dl>
<h2>Response types</h2>
<p>Append ?format=x to the end of your query to control the format<p>
<pFormats available:</p>
<ul>
<li>json</li>
<li>html</li>
</ul>
<p>Alternatively, use the "Accept" header.</p>
</div>
<!-- Latest compiled and minified JavaScript -->
<script src="https://code.jquery.com/jquery-1.11.3.min.js"></script>
<script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/js/bootstrap.min.js"></script>
</body>
</html>

@@ viewid.html.ep
<!DOCTYPE html>
<html>
<head>
<title><%= $dataset->full_accession %></title>
<link href="../favicon.ico" rel="icon" type="image/x-icon" />
<!-- Latest compiled and minified CSS -->
<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap.min.css">
<!-- Optional theme -->
<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap-theme.min.css"> 
</head>
<body>
<div class="container-fluid">
<h1><%= $dataset->full_accession %></h1>
<dl class="dl-horizontal">
  <dt>Type</dt><dd><%= $dataset->type %></dd>
  <dt>Status</dt><dd><%= $dataset->status %></dd>
  <dt>Project</dt><dd><%= $dataset->project %></dd>
  <dt>Local name</dt><dd><%= $dataset->local_name %></dd>
  <dt>Description</dt><dd><%= $dataset->description %></dd>
</dl>
<h2>Metadata</h2>
<dl class="dl-horizontal">
% for my $kv ($dataset->meta_data_kv) {
  <dt><%= $kv->[0] %></dt><dd><%= $kv->[1] %></dd>  
% }
</dl>
<h2>Raw data</h2>
<table class="table table-hover table-condensed table-striped">
<thead>
<tr>
<th>Assay type</th>
<th>Experiment type</th>
<th>Archive</th>
<th>Primary ID</th>
<th>Secondary ID</th>
<th>Link</th>
</tr>
</thead>
<tbody>
% for my $rd ($dataset->all_raw_data) {
  <tr>
  <td><%= $rd->assay_type %></td>
  <td><%= $rd->experiment_type %></td>
  <td><%= $rd->archive %></td>
  <td><%= $rd->primary_id %></td>
  <td><%= $rd->secondary_id %></td>
  <td><a href="<%= $rd->archive_url %>">View in archive</a></td>
  </tr>
% }
</tbody>
</table>
</div>
<!-- Latest compiled and minified JavaScript -->
<script src="https://code.jquery.com/jquery-1.11.3.min.js"></script>
<script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/js/bootstrap.min.js"></script>
</body>
</html>

@@ viewall.html.ep
<!DOCTYPE html>
<html>
<head>
<title>EpiRR Datasets</title>
<link href="../favicon.ico" rel="icon" type="image/x-icon" />
<!-- Latest compiled and minified CSS -->
<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap.min.css">
<!-- Optional theme -->
<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap-theme.min.css"> 
</head>
<body>
<div class="container-fluid">
<h1>EpiRR Datasets</h1>
<table class="table table-hover table-condensed table-striped">
<thead>
<tr>
<th>Project</th>
<th>Type</th>
<th>Status</th>
<th>ID</th>
<th>Local name</th>
<th>Description</th>
<th></th>
</tr>
</thead>
<tbody>
% for my $d (@$datasets) {
  <tr>
  <td><%= $d->project %></td>
  <td><%= $d->type %></td>
  <td><%= $d->status %></td>
  <td><%= $d->full_accession %></td>
  <td><%= $d->local_name %></td>
  <td><%= $d->description %></td>
  <td><a href="./<%= $d->full_accession %>">Detail</a></td>
  </tr>
% }
</tbody>
</table>
</div>
<!-- Latest compiled and minified JavaScript -->
<script src="https://code.jquery.com/jquery-1.11.3.min.js"></script>
<script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/js/bootstrap.min.js"></script>
</body>
</html>
