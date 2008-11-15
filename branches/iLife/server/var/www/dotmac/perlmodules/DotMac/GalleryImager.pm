#file:DotMac/GalleryImager.pm;
#-----------------------------

## Copyright (C) 2008 Walinsky
## This file is part of dotMac. 

## dotMac is free software: you can redistribute it and/or modify
## it under the terms of the Affero GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.

## dotMac is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## Affero GNU General Public License for more details.

## You should have received a copy of the Affero GNU General Public License
## along with Foobar.  If not, see <http://www.gnu.org/licenses/>.

package DotMac::GalleryImager;

use strict;
use warnings;

use Apache2::RequestUtil ();
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Const -compile => qw(OK);
use JSON;
use Imager;
use DotMac::CommonCode;
use File::stat;

# $DotMac::GalleryImager::VERSION = '0.1';

sub handler {
	my $r = shift;
	my $logging = $r->dir_config('LoggingTypes');
	my $rlog = $r->log;
	my $docroot = $r->document_root;
	my $derivative =  $r->notes->get('derivative');
	my $source =  $r->notes->get('source');
	my $type =  $r->notes->get('type');
	my $ver =  $r->notes->get('ver');
	my $uri = $r->uri;
	my $sourcepath = "$docroot/$uri/$source";
	if (($type eq 'exif') && (-f "$docroot/$uri/large.jpg")) {
		$sourcepath = "$docroot/$uri/large.jpg";
	}
	#my $destpath = "$docroot/$uri/$type.jpg";
	my $destpath = $r->filename;# this is set in GalleryTransHandler
	my $newimg;
	my $tmpimg;
	$logging =~ m/Sections/&&$rlog->info("GalleryImager::handler derivative: $derivative from $sourcepath");
	if (!(-f $destpath)) {
		$logging =~ m/Sections/&&$rlog->info("$destpath does not exist; creating from $source...");
		if (-f $sourcepath) {
			$logging =~ m/Sections/&&$rlog->info("$sourcepath exists");
			my $img = Imager->new();
			$img->read(file=>$sourcepath) or $logging =~ m/Sections/&&$rlog->error($img->errstr());
			if ($type eq 'medium')
				{
				$newimg = $img->scale(xpixels=>320,ypixels=>320, type=>'min');
				$newimg->write(file=>$destpath) or $logging =~ m/Sections/&&$rlog->error($newimg->errstr());
				$r->content_type('image/jpeg');
				}
			elsif ($type eq 'square')
				{
				$tmpimg = $img->scale(xpixels=>160,ypixels=>160);
				$newimg = $tmpimg->crop(width=>160, height=>160);
				$newimg->write(file=>$destpath) or $logging =~ m/Sections/&&$rlog->error($newimg->errstr());
				$r->content_type('image/jpeg');
				}
			elsif ($type eq 'exif')
				{
				
				my %resultdata = ( status => 1 ); # Warning: magic constant, no idea what it means...
				$resultdata{data}{infoSensing} = $img->tags(name => "exif_sensing_method");
				$resultdata{data}{infoExposure} = $img->tags(name => "exif_exposure_index");
				$resultdata{data}{infoFNumber} = $img->tags(name => "exif_f_number");
				$resultdata{data}{infoDistance} = $img->tags(name => "exif_subject_distance");
				$resultdata{data}{infoGPSLongitude} = "--";
				$resultdata{data}{infoWidth} = $img->getwidth();
				my @dirtree = split (/\//,$uri);
				my $numdir = @dirtree;
				my $filename = @dirtree[$numdir - 1 ];
				$resultdata{data}{infoName} = $filename;
				$resultdata{data}{infoDigitizedDate} = $img->tags(name => "exif_date_time_digitized");
				$resultdata{data}{infoGPSLongitudeRef} = "--";
				$resultdata{data}{infoFocalLength} = $img->tags(name => "exif_focal_length");
				$resultdata{data}{infoHeight} = $img->getheight();
				$resultdata{data}{infoExposureTime} = $img->tags(name => "exif_exposure_time");
				$resultdata{data}{infoGPSLatitude} = "--";
				$resultdata{data}{infoAperture} = $img->tags(name => "exif_aperture");
				$resultdata{data}{infoMetering} = $img->tags(name => "exif_metering_mode_name");
				$resultdata{data}{infoShutter} = $img->tags(name => "exif_shutter_speed");
				$resultdata{data}{infoSize} = DotMac::CommonCode::file_size(stat($sourcepath)->size);
				$resultdata{data}{infoBrightness} = $img->tags(name => "exif_brightness");
				$resultdata{data}{infoCameraModel} = "--";
				$resultdata{data}{infoMaxAperture} = $img->tags(name => "exif_max_aperture");
				$resultdata{data}{infoCameraMake} = $img->tags(name => "exif_make");
				$resultdata{data}{infoExposureBias} = $img->tags(name => "exif_exposure_bias");
				$resultdata{data}{infoFlash} = $img->tags(name => "exif_flash");
				$resultdata{data}{infoOriginalDate} = $img->tags(name => "exif_date_time_original");
				$resultdata{data}{infoGPSAltitude} = "--";
				$resultdata{data}{infoISOSpeed} = $img->tags(name => "exif_iso_speed_rating");
				$resultdata{data}{infoLightSource} = $img->tags(name => "exif_tag_light_source");
				$resultdata{data}{infoSoftware} = $img->tags(name => "exif_software");
				$resultdata{data}{infoGPSLatitudeRef} = "--";

				open (JSON, ">$destpath");
				print JSON to_json(\%resultdata, {pretty => 1});
				close (JSON);
				$r->content_type("application/json");
				}
		}
	}
	
	$r->sendfile("$destpath");
	return Apache2::Const::OK;
	}

1;
