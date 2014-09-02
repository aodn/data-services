# usage: perl rad2vec.pl directory_with_.xyz_files

chdir($ARGV[0]) or die "$!";
foreach $rad ('FRE','GUI') {
my ($file) = join '', "RADIALS",$rad,".xyz";
my ($ufile) = join '', "U",$rad,".xyz";
my ($vfile) = join '', "V",$rad,".xyz";
$pi = atan2(1,1)*4;
$dgr2rad = $pi/180;

open RADS, "< $file" or die "opening $rads\n";
my @lines = <RADS>;
close RADS;
open U, "> $ufile";
open V, "> $vfile";
foreach my $line (@lines)
{
    chomp $line;
    my ($pos,$lng,$lat,$spd,$dir) = split ' ',$line;
    my ($u) = $spd * sin ($dir*$dgr2rad);
    my ($v) = $spd * cos ($dir*$dgr2rad);
    if($u != 0){
    printf U "$lng,$lat,$u\n";
    printf V "$lng,$lat,$v\n";}
}
close U;
close V;
}
# Vectorise
my ($file1) = "RADIALSFRE.xyz";
my ($file2) = "RADIALSGUI.xyz";
my ($sfile) = "SPEED.xyz";
my ($ufile) = "U.xyz";
my ($vfile) = "V.xyz";
open RAD1, "< $file1" or die "opening $rads\n";
my @lines1 = <RAD1>;
close RAD1;
open RAD2, "< $file2" or die "opening $rads\n";
my @lines2 = <RAD2>;
close RAD2;
open S, "> $sfile";
open U, "> $ufile";
open V, "> $vfile";
foreach my $line1 (@lines1)
{
    chomp $line1;
    my ($pos1,$lng1,$lat1,$spd1,$dir1) = split ' ',$line1;
    if($spd1 != 0){
    foreach my $line2 (@lines2)
    {
	chomp $line2;
	my ($pos2,$lng2,$lat2,$spd2,$dir2) = split ' ',$line2;
	if($spd2 != 0){
	if($pos2 == $pos1){
	    $u = ($spd1 * cos( $dir2 * $dgr2rad) - $spd2 * cos( $dir1 * $dgr2rad))/sin( ($dir1 -$dir2) * $dgr2rad);
	    $v = ($spd2 * sin( $dir1 * $dgr2rad) - $spd1 * sin( $dir2 * $dgr2rad))/sin( ($dir1 -$dir2) * $dgr2rad);
	    $s = sqrt( $u * $u + $v * $v);
	    if($s < 2.){
	    printf S "$lng1,$lat1,$s\n";
	    printf U "$lng1,$lat1,$u\n";
	    printf V "$lng1,$lat1,$v\n";}
	    last;
	}}}
    }
}
close S;
close U;
close V;
