#!/usr/bin/perl

#
# Recurse through a directory tree validating all archive files for archive consistency. For
# archives with par sets containing archive files, just verify the par set (unless -d is specified).
# By default, verbosely list whats being done, or if -q is specified then just display errors.
#

# TO DO
# - Refactor. Reduce all the repeated code
# - Add ARJ support
# - Test again on Cygwin
# - Support RAR types which are split into multiple.rar files, e.g. .part001.rar .par002.rar rather than .rar .r01
# - if -q is specified, exit with returncode==number of errors

# Supports *.gz *.Z *.arc *.lha *.lzh *.zip *.rar *.par *.par2 *.tar *.bz2 *.tgz *.7z *.zoo *.cpio
# For Linux (Ubuntu)
#  sudo apt-get install perl gzip nomarch lhasa zip unzip rar unrar par2 tar bzip2 p7zip p7zip-full p7zip-rar zoo arj cpio
# For CygWin
#  Add packages perl/perl base/gzip archive/arc archive/zip archive/unzip base/tar utils/bzip2 archive/zoo utils/arj utils/cpio
#  Ensure that these two lines are in ~/.bashrc
#  alias unrar="/cygdrive/c/Program\ Files/WinRAR/UnRAR.exe"
#  alias 7z="/cygdrive/c/Program\ Files\ \(x86\)/7-Zip/7z.exe"

$uname =`uname -s`;
$is_linux = ($uname =~ /Linux/i);
$is_cygwin = ($uname =~ /CYGWIN/);

sub cmd_exists
{
  my ($binname) = @_;
  if (-e $binname)
    {
      return $binname;
    }
  else
   {
    my $whichout = `which $binname 2>/dev/null`;
    if ($whichout eq '') 
     { return ""; }
    else
     { return $binname; }
   }
}

if ($is_linux)
 {
  $gzipcmd = "gzip";
  $arccmd = "nomarch";
  $lharccmd = "lhasa";
  $unzipcmd = "unzip";
  $unrarcmd = "unrar";
  $par2cmd = "par2";
  $tarcmd = "tar";
  $bzip2cmd = "bzip2";
  $z7cmd = "7z";
  $zoocmd = "zoo";
  $arjcmd = "arj";
  $cpiocmd = "cpio";
 }
elsif ($is_cygwin)
 {
  $pf = '/cygdrive/c/Program\ Files'; $pf_strip = $pf; $pf_strip =~ s/\\//g;
  $pf86 = '/cygdrive/c/Program\ Files\ \(x86\)'; $pf86_strip = $pf86; $pf86_strip =~ s/\\//g;
  $gzipcmd = "gzip";
  $arccmd = "";
  $lharccmd = "";  # External
  $unzipcmd = "unzip";
  $unrarcmd = "";
  if (-e "$pf86_strip/WinRAR/UnRAR.exe")            # External
   { $unrarcmd = "$pf86/WinRAR/UnRAR.exe"; }
  elsif (-e "$pf_strip/WinRAR/UnRAR.exe") 
   { $unrarcmd = "$pf/WinRAR/UnRAR.exe"; }
  $par2cmd = "";
  if (-e "$pf86_strip/Par2Cmd/par2.exe")            # External
   { $par2cmd = "$pf86/Par2Cmd/par2.exe"; }
  elsif (-e "$pf_strip/Par2Cmd/par2.exe") 
   { $par2cmd = "$pf/Par2Cmd/par2.exe"; }
  $tarcmd = "tar";
  $bzip2cmd = "bzip2";
  $z7cmd = "";
  if (-e "$pf86_strip/7-Zip/7z.exe")                # External
   { $z7cmd = "$pf86/7-Zip/7z.exe"; }
  elsif (-e "$pf_strip/7-Zip/7z.exe") 
   { $z7cmd = "$pf/7-Zip/7z.exe"; }
  $zoocmd = "zoo";
  $arjcmd = "arj";
  $cpiocmd = "cpio";
 }
else
 {
  print "Unknown host OS type - $uname\n";
  exit(1);
 }

$gzipcmd = cmd_exists($gzipcmd);
$arccmd = cmd_exists($arccmd);
$lharccmd = cmd_exists($lharccmd);
$unzipcmd = cmd_exists($unzipcmd);
$unrarcmd = cmd_exists($unrarcmd);
$par2cmd = cmd_exists($par2cmd);
$tarcmd = cmd_exists($tarcmd);
$bzip2cmd = cmd_exists($bzip2cmd);
$z7cmd = cmd_exists($z7cmd);
$zoocmd = cmd_exists($zoocmd);
$arjcmd = cmd_exists($arjcmd);
$cpiocmd = cmd_exists($cpiocmd);

$quiet = 0;
$double_check = 0;
foreach $arg (@ARGV)
  {
    if ($arg eq '-q') { $quiet = 1; }
    elsif ($arg eq '-d') { $double_check = 1; }  # Check archive even if it was part of a PAR/PAR2 set
    else 
     {
       print "Invalid parameter $arg\n";
       exit (1);
     }
  }

open(FINDPAR, 'find . -iname "*.par" -o -iname "*.par2" |');
@pars = ();
while ($in = <FINDPAR>)
 {
  chomp($in);
  if (!($in =~ /vol[0-9]*\+[0-9]\.par/i)) { push(@pars, $in); }
 }
close(FINDPAR);
@pars = sort(@pars);

open(FINDARCH, 'find . -iname "*.gz" -o -iname "*.z" -o -iname "*.arc" -o -iname "*.lha" -o -iname "*.lzh" -o -iname "*.zip" -o -iname "*.rar" -o -iname "*.tar" -o -iname "*.bz2" -o -iname "*.tgz" -o -iname "*.7z" -o -iname "*.zoo" -o -iname "*.arj" -o -iname "*.cpio" |');
@archives = ();
while ($in = <FINDARCH>)
 {
  chomp($in);
  push(@archives, $in);
 }
close(FINDARCH);
@archives = sort(@archives);

$par_count = @pars;
$par_num = 0;
@par_tested = ();

if ($par2cmd ne "") 
 {
  foreach $par (@pars)
   {
    $par_num++;
    if (!$quiet) { print "Testing ${par_num}/${par_count} $par - "; }
    $ok = 0;
    @errs = ();
    open(PAR2OUT, "$par2cmd v \"$par\" 2>&1 |");
    while ($inp = <PAR2OUT>)
     {
       chomp($inp);
       $inp =~ s/\r|\n//g;
       if ($inp =~ /^All files are correct, repair is not required/) { $ok = 1 }
       elsif ($inp =~ /Target: "(.*)" - found/) { $fn = $1; push(@par_tested, $fn); }
       elsif ($inp =~ /Target: "(.*)" - damaged/) { $fn = $1; push(@par_tested, $fn); push(@errs, "Target: $fn - damaged"); }
       elsif ($inp =~ /^$/) { }
       elsif ($inp =~ /^\s*$/) { }
       elsif ($inp =~ /par2cmdline version ([0-9,\.]*)/) { }
       elsif ($inp =~ /par2cmdline comes with ABSOLUTELY NO WARRANTY/) { }
       elsif ($inp =~ /This is free software, and you are welcome to/) { }
       elsif ($inp =~ /it under the terms of the GNU General Public/) { }
       elsif ($inp =~ /Free Software Foundation; either version/) { }
       elsif ($inp =~ /any later version. See COPYING for details/) { }
       elsif ($inp =~ /Loading "(.*)"/) { }
       elsif ($inp =~ /Loaded ([0-9]*) new packet/) { }
       elsif ($inp =~ /There are [0-9]* recoverable file/) { }
       elsif ($inp =~ /There is [0-9]* recoverable file/) { }
       elsif ($inp =~ /The block size used was [0-9]* byte/) { }
       elsif ($inp =~ /There are a total of [0-9]* data blocks/) { }
       elsif ($inp =~ /There is a total of [0-9]* data block/) { }
       elsif ($inp =~ /The total size of the data files is [0-9]* bytes/) { }
       elsif ($inp =~ /Verifying source files:/) { }
       elsif ($inp =~ /Scanning extra files:/) { }
       elsif ($inp =~ /Repair is required/) { }
       elsif ($inp =~ /[0-9]* file(s) exist but are damaged/) { }
       elsif ($inp =~ /You have [0-9]* out of [0-9]* data blocks available/) { }
       elsif ($inp =~ /You have [0-9]* recovery blocks available/) { }
       elsif ($inp =~ /Repair is possible/) { }
       elsif ($inp =~ /You have an excess of [0-9]* recovery blocks/) { }
       elsif ($inp =~ /[0-9]* recovery blocks will be used to repair/) { }
       elsif ($inp =~ /[0-9]* file\(s\) exist but are damaged/) { }
       elsif ($inp =~ /From here onwards is par2cmd on Cygwin_windows/) { }
       elsif ($inp =~ /Modifications for concurrent processing, Unicode support, and hierarchial/) { }
       elsif ($inp =~ /directory support are Copyright/) { }
       elsif ($inp =~ /\(c\) (.*) Vincent Tan/) { }
       elsif ($inp =~ /Concurrent processing utilises Intel Thread Building Blocks/) { }
       elsif ($inp =~ /Copyright \(c\) (.*) Intel Corp/) { }
       elsif ($inp =~ /Executing using the 32-bit x86/) { }
       elsif ($inp =~ /Processing verifications and repairs concurrently/) { }
       
       else { push(@errs, $inp); }
     }
    if ($ok)
     { 
       if (!$quiet) { print "Ok, no errors\n" }
     }
    else
     {
       if ($quiet) {  print "Testing ${par_num}/${par_count} $par - "; }
       print "Errors!\n";
       foreach $err (@errs) { print ">$err>\n"; }
     }
   }
 }
else
 {
   print "Error - Cannot locate a PAR2 utility tool, PAR/PAR2 archive sets will not be processed\n";
 }

# Unless the "double-check" option was specified, remove anything checked as part of a PAR set from the archive list
if (!$double_check)
 {
   @new_archives = ();
   foreach $arch (@archives)
    {
      $was_par = 0;
      foreach $pt (@par_tested)
       {
         ($arch_fname = $arch) =~s/.*\///s;  # Strip path
         if ($pt eq $arch_fname) { $was_par = 1; }
       }
      if (!$was_par) { push(@new_archives, $arch); }
    }
   @archives = @new_archives;
 }

# Check archives
$archive_count = @archives;
$archive_num = 0;
foreach $arch (@archives)
 {
  $archive_num++;
  if (!$quiet) { print "Testing ${archive_num}/${archive_count} $arch - "; }
  $ext = "";
  if ($arch =~ /\.([a-z,0-9]*)$/) { $ext = $1; }
  $ok = 0;
  @errs = ();
  if (($ext =~ /zip/i) && ($unzipcmd ne ''))
    {
      open(ZIPOUT, "$unzipcmd -t \"$arch\" 2>&1 |");
      while ($inp = <ZIPOUT>)
        {
          chomp($inp);
          $inp =~ s/\r|\n//g;
          if ($inp =~ /^No errors detected in compressed data/) { $ok = 1 }
          elsif ($inp =~ /^Archive: /) { }
          elsif ($inp =~ / OK$/) { }
          elsif ($inp =~ /^$/) { }
          elsif ($inp =~ /^\s*$/) { }
          else { push(@errs, $inp) }
        }
      close(ZIPOUT);
      if ($ok)
        { 
          if (!$quiet) { print "Ok, no errors\n" }
        }
      else
        {
          if ($quiet) { print "Testing ${archive_num}/${archive_count} $arch - "; }
          print "Errors!\n";
          foreach $err (@errs) { print ">$err>\n"; }
        }
    }
  elsif (($ext =~ /rar/i) && ($unrarcmd ne ''))
    {
      open(RAROUT, "$unrarcmd t -idp \"$arch\" 2>&1 |");
      while ($inp = <RAROUT>)
        {
          chomp($inp);
          $inp =~ s/\r|\n//g;
          if ($inp =~ /^All OK/) { $ok = 1 }
          elsif ($inp =~ /^UNRAR [0-9]./) { }
          elsif ($inp =~ /^Testing archive /) {}
          elsif ($inp =~ /^$/) { }
          elsif ($inp =~ /^\s*$/) { }
          else { push(@errs, $inp) }
        }
      close(RAROUT);
      if ($ok)
        { 
          if (!$quiet) { print "Ok, no errors\n" }
        }
      else
        {
          if ($quiet) { print "Testing ${archive_num}/${archive_count} $arch - "; }
          print "Errors!\n";
          foreach $err (@errs) { print ">$err>\n"; }
        }
    }
  elsif ( (($ext =~ /7z/i) && ($z7cmd ne '')) || ($is_cygwin && (($ext =~ /lha/i) || ($ext =~ /lzh/i)) && ($z7cmd ne '')) )
    {
      open(Z7OUT, "$z7cmd t \"$arch\" 2>&1 |");
      while ($inp = <Z7OUT>)
        {
          chomp($inp);
          $inp =~ s/\r|\n//g;
          if ($inp =~ /^Everything is Ok/) { $ok = 1 }
          elsif ($inp =~ /^7-Zip /) { }
          elsif ($inp =~ /^p7zip Version/) { }
          elsif ($inp =~ /^Processing archive:/) {}
          elsif ($inp =~ /^$/) { }
          elsif ($inp =~ /^\s*$/) { }
          else { push(@errs, $inp) }
        }
      close(Z7OUT);
      if ($ok)
        { 
          if (!$quiet) { print "Ok, no errors\n" }
        }
      else
        {
          if ($quiet) { print "Testing ${archive_num}/${archive_count} $arch - "; }
          print "Errors!\n";
          foreach $err (@errs) { print ">$err>\n"; }
        }
    }
  elsif (($ext =~ /zoo/i) && ($zoocmd ne ''))
    {
      open(ZOOOUT, "$zoocmd -test \"$arch\" 2>&1 |");
      while ($inp = <ZOOOUT>)
        {
          chomp($inp);
          $inp =~ s/\r|\n//g;
          if ($inp =~ /Archive seems OK\.$/) { $ok = 1 }
          elsif ($inp =~ /^-- OK$/) { }
          elsif ($inp =~ /^$/) { }
          elsif ($inp =~ /^\s*$/) { }
          else { push(@errs, $inp) }
        }
      close(ZOOOUT);
      if ($ok)
        { 
          if (!$quiet) { print "Ok, no errors\n" }
        }
      else
        {
          if ($quiet) { print "Testing ${archive_num}/${archive_count} $arch - "; }
          print "Errors!\n";
          foreach $err (@errs) { print ">$err>\n"; }
        }
    }
  elsif ( (($ext =~ /lha/i) || ($ext =~ /lzh/i) ) && ($lharccmd ne '') && $is_linux)
    {
      open(LHAOUT, "$lharccmd t \"$arch\" 2>&1 |");
      $rec_bad = 0; $rec_good = 0;
      while ($inp = <LHAOUT>)
        {
          chomp($inp);
          $inp =~ s/\r|\n//g;
          if ($inp =~ /- Testing   :  \.+$/) { }
          elsif ($inp =~ /- Testing   :  o+$/) { }
          elsif ($inp =~ /- Tested\s+$/) { $rec_good++; }
          elsif ($inp =~ /^$/) { }
          elsif ($inp =~ /^\s*$/) { }
          else { $bad++; push(@errs, $inp) }
        }
      close(LHAOUT);
      $ok = (($rec_bad == 0) && ($rec_good > 0));
      if ($ok)
        { 
          if (!$quiet) { print "Ok, no errors\n" }
        }
      else
        {
          if ($quiet) { print "Testing ${archive_num}/${archive_count} $arch - "; }
          print "Errors!\n";
          foreach $err (@errs) { print ">$err>\n"; }
        }
    }
  elsif (($ext =~ /arj/i) && ($arjcmd ne ''))
    {
      $rec_bad = 0; $rec_good = 0;
      open(ARJOUT, "$arjcmd t \"$arch\" 2>&1 |");
      while ($inp = <ARJOUT>)
        {
          chomp($inp);
          $inp =~ s/\r|\n//g;
          if ($inp =~ /^ARJ32 v /) { }
          elsif ($inp =~ /^Archive created:/) { }
          elsif ($inp =~ /Processing archive: /) { }
          elsif ($inp =~ /\s*OK\s*/) { $rec_good++; }
          elsif ($inp =~ /^$/) { }
          elsif ($inp =~ /^\s{1,}/) { }
          elsif ($inp =~ /^\s*[0-9]*\sfile\(s/) { }
          else { $bad++; push(@errs, $inp); $rec_bad++ }
        }
      close(ARJOUT);
      $ok = (($rec_bad == 0) && ($rec_good > 0));
      if ($ok)
        { 
          if (!$quiet) { print "Ok, no errors\n" }
        }
      else
        {
          if ($quiet) { print "Testing ${archive_num}/${archive_count} $arch - "; }
          print "Errors!\n";
          foreach $err (@errs) { print ">$err>\n"; }
        }
    }
  elsif (($ext =~ /arc/i) && ($arccmd ne ''))
    {
      open(ARCOUT, "$arccmd -t \"$arch\" 2>&1 |");
      while ($inp = <ARCOUT>)
        {
          chomp($inp);
          $inp =~ s/\r|\n//g;
          if ($inp =~ /\s*ok$/) { }
          elsif ($inp =~ /^$/) { }
          elsif ($inp =~ /^\s*$/) { }
          else { push(@errs, $inp); }
        }
      close(ARCOUT);
      $err_cnt = @errs;
      $ok = ($err_cnt == 0);
      if ($ok)
        { 
          if (!$quiet) { print "Ok, no errors\n" }
        }
      else
        {
          if ($quiet) { print "Testing ${archive_num}/${archive_count} $arch - "; }
          print "Errors!\n";
          foreach $err (@errs) { print ">$err>\n"; }
        }
    }
  elsif (($ext =~ /gz/i) && ($gzipcmd ne ''))
    {
      open(GZIPOUT, "$gzipcmd -t \"$arch\" 2>&1 |");
      while ($inp = <GZIPOUT>)
        {
          chomp($inp);
          $inp =~ s/\r|\n//g;
          if ($inp =~ /^$/) { }
          elsif ($inp =~ /^\s*$/) { }
          else { push(@errs, $inp) }
        }
      close(GZIPOUT);
      $rc = $?;
      if ($rc == 0)
        { 
          if (!$quiet) { print "Ok, no errors\n" }
        }
      else
        {
          if ($quiet) { print "Testing ${archive_num}/${archive_count} $arch - "; }
          print "Errors!\n";
          foreach $err (@errs) { print ">$err>\n"; }
        }
    }
  elsif (($ext =~ /bz2/i) && ($bzip2cmd ne ''))
    {
      open(BZIP2OUT, "$bzip2cmd -t \"$arch\" 2>&1 |");
      while ($inp = <BZIP2OUT>)
        {
          chomp($inp);
          $inp =~ s/\r|\n//g;
          if ($inp =~ /^$/) { }
          elsif ($inp =~ /^\s*$/) { }
          else { push(@errs, $inp) }
        }
      close(BZIP2OUT);
      $rc = $?;
      if ($rc == 0)
        { 
          if (!$quiet) { print "Ok, no errors\n" }
        }
      else
        {
          if ($quiet) { print "Testing ${archive_num}/${archive_count} $arch - "; }
          print "Errors!\n";
          foreach $err (@errs) { print ">$err>\n"; }
        }
    }
  elsif (($ext =~ /tar/i) && ($tarcmd ne ''))
    {
      open(TAROUT, "$tarcmd tf \"$arch\" 2>&1 |");
      while ($inp = <TAROUT>)
        {
          chomp($inp);
          $inp =~ s/\r|\n//g;
          if ($inp =~ /^$/) { }
          elsif ($inp =~ /^\s*$/) { }
          else { push(@errs, $inp) }
        }
      close(TAROUT);
      $rc = $?;
      if ($rc == 0)
        { 
          if (!$quiet) { print "Ok, no errors\n" }
        }
      else
        {
          if ($quiet) { print "Testing ${archive_num}/${archive_count} $arch - "; }
          print "Errors!\n";
          foreach $err (@errs) { print ">$err>\n"; }
        }
    }
  elsif (($ext =~ /cpio/i) && ($cpiocmd ne ''))
    {
      open(CPIOOUT, "$cpiocmd -t <\"$arch\" 2>&1 |");
      while ($inp = <CPIOOUT>)
        {
          chomp($inp);
          $inp =~ s/\r|\n//g;
          if ($inp =~ /^$/) { }
          elsif ($inp =~ /^\s*$/) { }
          else { push(@errs, $inp) }
        }
      close(CPIOOUT);
      $rc = $?;
      if ($rc == 0)
        { 
          if (!$quiet) { print "Ok, no errors\n" }
        }
      else
        {
          if ($quiet) { print "Testing ${archive_num}/${archive_count} $arch - "; }
          print "Errors!\n";
          foreach $err (@errs) { print ">$err>\n"; }
        }
    }
  else
    {
      if ($quiet) { print "Testing ${archive_num}/${archive_count} $arch - "; }
      print " - Unsupported filetype ($ext)\n";
    }
 }

