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
use Image::ExifTool;

  
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
	$logging =~ m/Sections/&&$rlog->debug("GalleryImager::handler derivative: $derivative from $sourcepath");
	if (!(-f $destpath)) {
		$logging =~ m/Sections/&&$rlog->debug("$destpath does not exist; creating from $source...");
		if (-f $sourcepath) {
			$logging =~ m/Sections/&&$rlog->debug("$sourcepath exists");
			
			
			if ($type eq 'medium')
				{
				my $img = Imager->new();
				$img->read(file=>$sourcepath) or $logging =~ m/Sections/&&$rlog->error($img->errstr());
				$newimg = $img->scale(xpixels=>320,ypixels=>320, type=>'min');
				$newimg->write(file=>$destpath) or $logging =~ m/Sections/&&$rlog->error($newimg->errstr());
				$r->content_type('image/jpeg');
				}
			elsif ($type eq 'square')
				{
				my $img = Imager->new();
				$img->read(file=>$sourcepath) or $logging =~ m/Sections/&&$rlog->error($img->errstr());
				$tmpimg = $img->scale(xpixels=>160,ypixels=>160);
				$newimg = $tmpimg->crop(width=>160, height=>160);
				$newimg->write(file=>$destpath) or $logging =~ m/Sections/&&$rlog->error($newimg->errstr());
				$r->content_type('image/jpeg');
				}
			elsif ($type eq 'exif')
				{
				my $exifTool = new Image::ExifTool;
				$exifTool->ImageInfo($sourcepath);

				my %resultdata = ( status => 1 ); # Warning: magic constant, no idea what it means...
				
				my @dirtree = split (/\//,$uri);
				my $numdir = @dirtree;
				my $filename = @dirtree[$numdir - 1 ];
				$resultdata{data}{infoName} = $filename;
				$resultdata{data}{infoDigitizedDate} = $exifTool->GetValue('CreateDate') || "--";
				$resultdata{data}{infoFocalLength} = $exifTool->GetValue('FocalLength') || "--";
				$resultdata{data}{infoHeight} = $exifTool->GetValue('ImageHeight') || "--";
				$resultdata{data}{infoWidth} = $exifTool->GetValue('ImageWidth') || "--";
				$resultdata{data}{infoCameraMake} = $exifTool->GetValue('Make') || "--";
				$resultdata{data}{infoCameraModel} = $exifTool->GetValue('Model') || "--";
				$resultdata{data}{infoSoftware} = $exifTool->GetValue('Software') || "--";
				$resultdata{data}{infoGPSLatitude} = $exifTool->GetValue('GPSLatitude') || "--";
				$resultdata{data}{infoGPSLatitudeRef} = $exifTool->GetValue('GPSLatitudeRef') || "--";
				$resultdata{data}{infoGPSLongitude} = $exifTool->GetValue('GPSLongitude') || "--";
				$resultdata{data}{infoGPSLongitudeRef} = $exifTool->GetValue('GPSLongitudeRef') || "--";
				$resultdata{data}{infoGPSAltitude} = $exifTool->GetValue('GPSAltitude') || "--";
				$resultdata{data}{infoAperture} = $exifTool->GetValue('ApertureValue') || "--";
				$resultdata{data}{infoMetering} = $exifTool->GetValue('MeteringMode') || "--";
=begin METERINGMODETXT
0 = Unknown 
1 = Average 
2 = Center-weighted average 
3 = Spot 
4 = Multi-spot 
5 = Multi-segment 
6 = Partial 
255 = Other
=end METERINGMODETXT
=cut
				$resultdata{data}{infoShutter} = $exifTool->GetValue('ShutterSpeedValue') || "--";
				$resultdata{data}{infoSize} = DotMac::CommonCode::file_size(stat($sourcepath)->size);
				$resultdata{data}{infoBrightness} = $exifTool->GetValue('Brightness') || "--";
				$resultdata{data}{infoSensing} = $exifTool->GetValue('SensingMethod') || "--";
				$resultdata{data}{infoFNumber} = $exifTool->GetValue('FNumber') || "--";
				$resultdata{data}{infoDistance} = $exifTool->GetValue('SubjectDistance') || "--";
				$resultdata{data}{infoMaxAperture} = $exifTool->GetValue('MaxApertureValue') || "--";
				$resultdata{data}{infoExposure} = $exifTool->GetValue('ExposureProgram') || "--";
				$resultdata{data}{infoExposureIndex} = $exifTool->GetValue('ExposureIndex') || "--";
				$resultdata{data}{infoExposureBias} = $exifTool->GetValue('ExposureCompensation') || "--"; # what the heck should this be ??
				$resultdata{data}{infoExposureTime} = $exifTool->GetValue('ExposureTime') || "--";
				$resultdata{data}{infoFlash} = $exifTool->GetValue('Flash') || "--";
				$resultdata{data}{infoOriginalDate} = $exifTool->GetValue('DateTimeOriginal') || "--";
				$resultdata{data}{infoISOSpeed} = $exifTool->GetValue('ISO') || "--";
				$resultdata{data}{infoLightSource} = $exifTool->GetValue('LightSource') || "--";

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
