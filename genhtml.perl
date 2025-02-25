#!/usr/bin/perl -w
#
#   Copyright (c) International Business Machines  Corp., 2002,2012
#
#   This program is free software;  you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or (at
#   your option) any later version.
#
#   This program is distributed in the hope that it will be useful, but
#   WITHOUT ANY WARRANTY;  without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#   General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program;  if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
#
# genhtml
#
#   This script generates HTML output from .info files as created by the
#   geninfo script. Call it with --help and refer to the genhtml man page
#   to get information on usage and available options.
#
#
# History:
#   2002-08-23 created by Peter Oberparleiter <Peter.Oberparleiter@de.ibm.com>
#                         IBM Lab Boeblingen
#        based on code by Manoj Iyer <manjo@mail.utexas.edu> and
#                         Megan Bock <mbock@us.ibm.com>
#                         IBM Austin
#   2002-08-27 / Peter Oberparleiter: implemented frame view
#   2002-08-29 / Peter Oberparleiter: implemented test description filtering
#                so that by default only descriptions for test cases which
#                actually hit some source lines are kept
#   2002-09-05 / Peter Oberparleiter: implemented --no-sourceview
#   2002-09-05 / Mike Kobler: One of my source file paths includes a "+" in
#                the directory name.  I found that genhtml.pl died when it
#                encountered it. I was able to fix the problem by modifying
#                the string with the escape character before parsing it.
#   2002-10-26 / Peter Oberparleiter: implemented --num-spaces
#   2003-04-07 / Peter Oberparleiter: fixed bug which resulted in an error
#                when trying to combine .info files containing data without
#                a test name
#   2003-04-10 / Peter Oberparleiter: extended fix by Mike to also cover
#                other special characters
#   2003-04-30 / Peter Oberparleiter: made info write to STDERR, not STDOUT
#   2003-07-10 / Peter Oberparleiter: added line checksum support
#   2004-08-09 / Peter Oberparleiter: added configuration file support
#   2005-03-04 / Cal Pierog: added legend to HTML output, fixed coloring of
#                "good coverage" background
#   2006-03-18 / Marcus Boerger: added --custom-intro, --custom-outro and
#                overwrite --no-prefix if --prefix is present
#   2006-03-20 / Peter Oberparleiter: changes to custom_* function (rename
#                to html_prolog/_epilog, minor modifications to implementation),
#                changed prefix/noprefix handling to be consistent with current
#                logic
#   2006-03-20 / Peter Oberparleiter: added --html-extension option
#   2008-07-14 / Tom Zoerner: added --function-coverage command line option;
#                added function table to source file page
#   2008-08-13 / Peter Oberparleiter: modified function coverage
#                implementation (now enabled per default),
#                introduced sorting option (enabled per default)
#   2014-09-12 / VaL Doroshchuk: ported to Windows
#

use strict;
use File::Basename;
use File::Temp qw(tempfile);
use Getopt::Long;
use Digest::MD5 qw(md5_base64);


# Global constants
our $title            = "LCOV - code coverage report";
our $lcov_version    = 'LCOV version 1.11';
our $lcov_url        = "http://ltp.sourceforge.net/coverage/lcov.php";
our $tool_name        = basename($0);

# Specify coverage rate limits (in %) for classifying file entries
# HI:   $hi_limit <= rate <= 100          graph color: green
# MED: $med_limit <= rate <  $hi_limit    graph color: orange
# LO:          0  <= rate <  $med_limit   graph color: red

# For line coverage/all coverage types if not specified
our $hi_limit = 90;
our $med_limit = 75;

# For function coverage
our $fn_hi_limit;
our $fn_med_limit;

# For branch coverage
our $br_hi_limit;
our $br_med_limit;

# Width of overview image
our $overview_width = 80;

# Resolution of overview navigation: this number specifies the maximum
# difference in lines between the position a user selected from the overview
# and the position the source code window is scrolled to.
our $nav_resolution = 4;

# Clicking a line in the overview image should show the source code view at
# a position a bit further up so that the requested line is not the first
# line in the window. This number specifies that offset in lines.
our $nav_offset = 10;

# Clicking on a function name should show the source code at a position a
# few lines before the first line of code of that function. This number
# specifies that offset in lines.
our $func_offset = 2;

our $overview_title = "top level";

# Width for line coverage information in the source code view
our $line_field_width = 12;

# Width for branch coverage information in the source code view
our $br_field_width = 16;

# Internal Constants

# Header types
our $HDR_DIR        = 0;
our $HDR_FILE        = 1;
our $HDR_SOURCE        = 2;
our $HDR_TESTDESC    = 3;
our $HDR_FUNC        = 4;

# Sort types
our $SORT_FILE        = 0;
our $SORT_LINE        = 1;
our $SORT_FUNC        = 2;
our $SORT_BRANCH    = 3;

# Fileview heading types
our $HEAD_NO_DETAIL    = 1;
our $HEAD_DETAIL_HIDDEN    = 2;
our $HEAD_DETAIL_SHOWN    = 3;

# Offsets for storing branch coverage data in vectors
our $BR_BLOCK        = 0;
our $BR_BRANCH        = 1;
our $BR_TAKEN        = 2;
our $BR_VEC_ENTRIES    = 3;
our $BR_VEC_WIDTH    = 32;
our $BR_VEC_MAX        = vec(pack('b*', 1 x $BR_VEC_WIDTH), 0, $BR_VEC_WIDTH);

# Additional offsets used when converting branch coverage data to HTML
our $BR_LEN    = 3;
our $BR_OPEN    = 4;
our $BR_CLOSE    = 5;

# Branch data combination types
our $BR_SUB = 0;
our $BR_ADD = 1;

# Error classes which users may specify to ignore during processing
our $ERROR_SOURCE    = 0;
our %ERROR_ID = (
    "source" => $ERROR_SOURCE,
);

# Data related prototypes
sub print_usage(*);
sub gen_html();
sub html_create($$);
sub process_dir($);
sub process_file($$$);
sub info(@);
sub read_info_file($);
sub get_info_entry($);
sub set_info_entry($$$$$$$$$;$$$$$$);
sub get_prefix($@);
sub shorten_prefix($);
sub get_dir_list(@);
sub get_relative_base_path($);
sub read_testfile($);
sub get_date_string();
sub create_sub_dir($);
sub subtract_counts($$);
sub add_counts($$);
sub apply_baseline($$);
sub remove_unused_descriptions();
sub get_found_and_hit($);
sub get_affecting_tests($$$);
sub combine_info_files($$);
sub merge_checksums($$$);
sub combine_info_entries($$$);
sub apply_prefix($$);
sub system_no_output($@);
sub read_config($);
sub apply_config($);
sub get_html_prolog($);
sub get_html_epilog($);
sub write_dir_page($$$$$$$$$$$$$$$$$);
sub classify_rate($$$$);
sub br_taken_add($$);
sub br_taken_sub($$);
sub br_ivec_len($);
sub br_ivec_get($$);
sub br_ivec_push($$$$);
sub combine_brcount($$$);
sub get_br_found_and_hit($);
sub warn_handler($);
sub die_handler($);
sub parse_ignore_errors(@);
sub rate($$;$$$);


# HTML related prototypes
sub escape_html($);
sub get_bar_graph_code($$$);

sub write_png_files();
sub write_htaccess_file();
sub write_css_file();
sub write_description_file($$$$$$$);
sub write_function_table(*$$$$$$$$$$);

sub write_html(*$);
sub write_html_prolog(*$$);
sub write_html_epilog(*$;$);

sub write_header(*$$$$$$$$$$);
sub write_header_prolog(*$);
sub write_header_line(*@);
sub write_header_epilog(*$);

sub write_file_table(*$$$$$$$);
sub write_file_table_prolog(*$@);
sub write_file_table_entry(*$$$@);
sub write_file_table_detail_entry(*$@);
sub write_file_table_epilog(*);

sub write_test_table_prolog(*$);
sub write_test_table_entry(*$$);
sub write_test_table_epilog(*);

sub write_source($$$$$$$);
sub write_source_prolog(*);
sub write_source_line(*$$$$$$);
sub write_source_epilog(*);

sub write_frameset(*$$$);
sub write_overview_line(*$$$);
sub write_overview(*$$$$);

# External prototype (defined in genpng)
sub gen_png($$$@);


# Global variables & initialization
our %info_data;        # Hash containing all data from .info file
our $dir_prefix;    # Prefix to remove from all sub directories
our %test_description;    # Hash containing test descriptions if available
our $date = get_date_string();

our @info_filenames;    # List of .info files to use as data source
our $test_title;    # Title for output as written to each page header
our $output_directory;    # Name of directory in which to store output
our $base_filename;    # Optional name of file containing baseline data
our $desc_filename;    # Name of file containing test descriptions
our $css_filename;    # Optional name of external stylesheet file to use
our $quiet;        # If set, suppress information messages
our $help;        # Help option flag
our $version;        # Version option flag
our $show_details;    # If set, generate detailed directory view
our $no_prefix;        # If set, do not remove filename prefix
our $func_coverage;    # If set, generate function coverage statistics
our $no_func_coverage;    # Disable func_coverage
our $br_coverage;    # If set, generate branch coverage statistics
our $no_br_coverage;    # Disable br_coverage
our $sort = 1;        # If set, provide directory listings with sorted entries
our $no_sort;        # Disable sort
our $frames;        # If set, use frames for source code view
our $keep_descriptions;    # If set, do not remove unused test case descriptions
our $no_sourceview;    # If set, do not create a source code view for each file
our $highlight;        # If set, highlight lines covered by converted data only
our $legend;        # If set, include legend in output
our $tab_size = 8;    # Number of spaces to use in place of tab
our $config;        # Configuration file contents
our $html_prolog_file;    # Custom HTML prolog file (up to and including <body>)
our $html_epilog_file;    # Custom HTML epilog file (from </body> onwards)
our $html_prolog;    # Actual HTML prolog
our $html_epilog;    # Actual HTML epilog
our $html_ext = "html";    # Extension for generated HTML files
our $html_gzip = 0;    # Compress with gzip
our $demangle_cpp = 0;    # Demangle C++ function names
our @opt_ignore_errors;    # Ignore certain error classes during processing
our @ignore;
our $opt_config_file;    # User-specified configuration file location
our %opt_rc;
our $charset = "UTF-8";    # Default charset for HTML pages
our @fileview_sortlist;
our @fileview_sortname = ("", "-sort-l", "-sort-f", "-sort-b");
our @funcview_sortlist;
our @rate_name = ("Lo", "Med", "Hi");
our @rate_png = ("ruby.png", "amber.png", "emerald.png");
our $lcov_func_coverage = 1;
our $lcov_branch_coverage = 0;
our $rc_desc_html = 0;    # lcovrc: genhtml_desc_html

our $cwd = `pwd`;    # Current working directory
chomp($cwd);
our $tool_dir = dirname($0);    # Directory where genhtml tool is installed

# @todo Needs to be changed
our $cppfilt = $cwd . "c++filt.exe";
sub uniq {
    my @unique;
    my %seen;
    foreach my $value (@{$_[0]}) {
        $value =~ s/[\/\\]+$//;
        $value =~ s/\/\//\//;
        if (! $seen{$value}++ ) {
            push @unique, $value;
        }
    }

    return @unique;
}

#
# Code entry point
#

$SIG{__WARN__} = \&warn_handler;
$SIG{__DIE__} = \&die_handler;

# Prettify version string
$lcov_version =~ s/\$\s*Revision\s*:?\s*(\S+)\s*\$/$1/;

# Add current working directory if $tool_dir is not already an absolute path
if (! ($tool_dir =~ /^\/(.*)$/))
{
    $tool_dir = "$cwd/$tool_dir";
}

# Check command line for a configuration file name
Getopt::Long::Configure("pass_through", "no_auto_abbrev");
GetOptions("config-file=s" => \$opt_config_file,
       "rc=s%" => \%opt_rc);
Getopt::Long::Configure("default");

# Read configuration file if available
if (defined($opt_config_file)) {
    $config = read_config($opt_config_file);
} elsif (defined($ENV{"HOME"}) && (-r $ENV{"HOME"}."/.lcovrc"))
{
    $config = read_config($ENV{"HOME"}."/.lcovrc");
}
elsif (-r "/etc/lcovrc")
{
    $config = read_config("/etc/lcovrc");
}

if ($config || %opt_rc)
{
    # Copy configuration file and --rc values to variables
    apply_config({
        "genhtml_css_file"        => \$css_filename,
        "genhtml_hi_limit"        => \$hi_limit,
        "genhtml_med_limit"        => \$med_limit,
        "genhtml_line_field_width"    => \$line_field_width,
        "genhtml_overview_width"    => \$overview_width,
        "genhtml_nav_resolution"    => \$nav_resolution,
        "genhtml_nav_offset"        => \$nav_offset,
        "genhtml_keep_descriptions"    => \$keep_descriptions,
        "genhtml_no_prefix"        => \$no_prefix,
        "genhtml_no_source"        => \$no_sourceview,
        "genhtml_num_spaces"        => \$tab_size,
        "genhtml_highlight"        => \$highlight,
        "genhtml_legend"        => \$legend,
        "genhtml_html_prolog"        => \$html_prolog_file,
        "genhtml_html_epilog"        => \$html_epilog_file,
        "genhtml_html_extension"    => \$html_ext,
        "genhtml_html_gzip"        => \$html_gzip,
        "genhtml_function_hi_limit"    => \$fn_hi_limit,
        "genhtml_function_med_limit"    => \$fn_med_limit,
        "genhtml_function_coverage"    => \$func_coverage,
        "genhtml_branch_hi_limit"    => \$br_hi_limit,
        "genhtml_branch_med_limit"    => \$br_med_limit,
        "genhtml_branch_coverage"    => \$br_coverage,
        "genhtml_branch_field_width"    => \$br_field_width,
        "genhtml_sort"            => \$sort,
        "genhtml_charset"        => \$charset,
        "genhtml_desc_html"        => \$rc_desc_html,
        "lcov_function_coverage"    => \$lcov_func_coverage,
        "lcov_branch_coverage"        => \$lcov_branch_coverage,
        });
}

# Copy related values if not specified
$fn_hi_limit    = $hi_limit if (!defined($fn_hi_limit));
$fn_med_limit    = $med_limit if (!defined($fn_med_limit));
$br_hi_limit    = $hi_limit if (!defined($br_hi_limit));
$br_med_limit    = $med_limit if (!defined($br_med_limit));
$func_coverage    = $lcov_func_coverage if (!defined($func_coverage));
$br_coverage    = $lcov_branch_coverage if (!defined($br_coverage));

# Parse command line options
if (!GetOptions("output-directory|o=s"    => \$output_directory,
        "title|t=s"        => \$test_title,
        "description-file|d=s"    => \$desc_filename,
        "keep-descriptions|k"    => \$keep_descriptions,
        "css-file|c=s"        => \$css_filename,
        "baseline-file|b=s"    => \$base_filename,
        "prefix|p=s"        => \$dir_prefix,
        "num-spaces=i"        => \$tab_size,
        "no-prefix"        => \$no_prefix,
        "no-sourceview"        => \$no_sourceview,
        "show-details|s"    => \$show_details,
        "frames|f"        => \$frames,
        "highlight"        => \$highlight,
        "legend"        => \$legend,
        "quiet|q"        => \$quiet,
        "help|h|?"        => \$help,
        "version|v"        => \$version,
        "html-prolog=s"        => \$html_prolog_file,
        "html-epilog=s"        => \$html_epilog_file,
        "html-extension=s"    => \$html_ext,
        "html-gzip"        => \$html_gzip,
        "function-coverage"    => \$func_coverage,
        "no-function-coverage"    => \$no_func_coverage,
        "branch-coverage"    => \$br_coverage,
        "no-branch-coverage"    => \$no_br_coverage,
        "sort"            => \$sort,
        "no-sort"        => \$no_sort,
        "demangle-cpp"        => \$demangle_cpp,
        "ignore-errors=s"    => \@opt_ignore_errors,
        "config-file=s"        => \$opt_config_file,
        "rc=s%"            => \%opt_rc,
        ))
{
    print(STDERR "Use $tool_name --help to get usage information\n");
    exit(1);
} else {
    # Merge options
    if ($no_func_coverage) {
        $func_coverage = 0;
    }
    if ($no_br_coverage) {
        $br_coverage = 0;
    }

    # Merge sort options
    if ($no_sort) {
        $sort = 0;
    }
}

@info_filenames = @ARGV;

# Check for help option
if ($help)
{
    print_usage(*STDOUT);
    exit(0);
}

# Check for version option
if ($version)
{
    print("$tool_name: $lcov_version\n");
    exit(0);
}

# Determine which errors the user wants us to ignore
parse_ignore_errors(@opt_ignore_errors);

# Check for info filename
if (!@info_filenames)
{
    die("No filename specified\n".
        "Use $tool_name --help to get usage information\n");
}

# Generate a title if none is specified
if (!$test_title)
{
    if (scalar(@info_filenames) == 1)
    {
        # Only one filename specified, use it as title
        $test_title = basename($info_filenames[0]);
    }
    else
    {
        # More than one filename specified, used default title
        $test_title = "unnamed";
    }
}

# Make sure css_filename is an absolute path (in case we're changing
# directories)
if ($css_filename)
{
    if (!($css_filename =~ /^\/(.*)$/))
    {
        $css_filename = $cwd."/".$css_filename;
    }
}

# Make sure tab_size is within valid range
if ($tab_size < 1)
{
    print(STDERR "ERROR: invalid number of spaces specified: ".
             "$tab_size!\n");
    exit(1);
}

# Get HTML prolog and epilog
$html_prolog = get_html_prolog($html_prolog_file);
$html_epilog = get_html_epilog($html_epilog_file);

# Issue a warning if --no-sourceview is enabled together with --frames
if ($no_sourceview && defined($frames))
{
    warn("WARNING: option --frames disabled because --no-sourceview ".
         "was specified!\n");
    $frames = undef;
}

# Issue a warning if --no-prefix is enabled together with --prefix
if ($no_prefix && defined($dir_prefix))
{
    warn("WARNING: option --prefix disabled because --no-prefix was ".
         "specified!\n");
    $dir_prefix = undef;
}

@fileview_sortlist = ($SORT_FILE);
@funcview_sortlist = ($SORT_FILE);

if ($sort) {
    push(@fileview_sortlist, $SORT_LINE);
    push(@fileview_sortlist, $SORT_FUNC) if ($func_coverage);
    push(@fileview_sortlist, $SORT_BRANCH) if ($br_coverage);
    push(@funcview_sortlist, $SORT_LINE);
}

if ($frames)
{
    # Include genpng code needed for overview image generation
    do("$tool_dir/genpng");
}

# Ensure that the c++filt tool is available when using --demangle-cpp
if ($demangle_cpp)
{
    if (system_no_output(3, $cppfilt, "--version")) {
        die("ERROR: could not find c++filt tool needed for ".
            "--demangle-cpp\n");
    }
}

# Make sure output_directory exists, create it if necessary
if ($output_directory)
{
    stat($output_directory);

    if (! -e _)
    {
        create_sub_dir($output_directory);
    }
}

# Do something
gen_html();

exit(0);



#
# print_usage(handle)
#
# Print usage information.
#

sub print_usage(*)
{
    local *HANDLE = $_[0];

    print(HANDLE <<END_OF_USAGE);
Usage: $tool_name [OPTIONS] INFOFILE(S)

Create HTML output for coverage data found in INFOFILE. Note that INFOFILE
may also be a list of filenames.

Misc:
  -h, --help                        Print this help, then exit
  -v, --version                     Print version number, then exit
  -q, --quiet                       Do not print progress messages
      --config-file FILENAME        Specify configuration file location
      --rc SETTING=VALUE            Override configuration file setting
      --ignore-errors ERRORS        Continue after ERRORS (source)

Operation:
  -o, --output-directory OUTDIR     Write HTML output to OUTDIR
  -s, --show-details                Generate detailed directory view
  -d, --description-file DESCFILE   Read test case descriptions from DESCFILE
  -k, --keep-descriptions           Do not remove unused test descriptions
  -b, --baseline-file BASEFILE      Use BASEFILE as baseline file
  -p, --prefix PREFIX               Remove PREFIX from all directory names
      --no-prefix                   Do not remove prefix from directory names
      --(no-)function-coverage      Enable (disable) function coverage display
      --(no-)branch-coverage        Enable (disable) branch coverage display

HTML output:
  -f, --frames                      Use HTML frames for source code view
  -t, --title TITLE                 Display TITLE in header of all pages
  -c, --css-file CSSFILE            Use external style sheet file CSSFILE
      --no-source                   Do not create source code view
      --num-spaces NUM              Replace tabs with NUM spaces in source view
      --highlight                   Highlight lines with converted-only data
      --legend                      Include color legend in HTML output
      --html-prolog FILE            Use FILE as HTML prolog for generated pages
      --html-epilog FILE            Use FILE as HTML epilog for generated pages
      --html-extension EXT          Use EXT as filename extension for pages
      --html-gzip                   Use gzip to compress HTML
      --(no-)sort                   Enable (disable) sorted coverage views
      --demangle-cpp                Demangle C++ function names

For more information see: $lcov_url
END_OF_USAGE
    ;
}


#
# get_rate(found, hit)
#
# Return a relative value for the specified found&hit values
# which is used for sorting the corresponding entries in a
# file list.
#

sub get_rate($$)
{
    my ($found, $hit) = @_;

    if ($found == 0) {
        return 10000;
    }
    return int($hit * 1000 / $found) * 10 + 2 - (1 / $found);
}


#
# get_overall_line(found, hit, name_singular, name_plural)
#
# Return a string containing overall information for the specified
# found/hit data.
#

sub get_overall_line($$$$)
{
    my ($found, $hit, $name_sn, $name_pl) = @_;
    my $name;

    return "no data found" if (!defined($found) || $found == 0);
    $name = ($found == 1) ? $name_sn : $name_pl;
    return rate($hit, $found, "% ($hit of $found $name)");
}


#
# print_overall_rate(ln_do, ln_found, ln_hit, fn_do, fn_found, fn_hit, br_do
#                    br_found, br_hit)
#
# Print overall coverage rates for the specified coverage types.
#

sub print_overall_rate($$$$$$$$$)
{
    my ($ln_do, $ln_found, $ln_hit, $fn_do, $fn_found, $fn_hit,
        $br_do, $br_found, $br_hit) = @_;

    info("Overall coverage rate:\n");
    info("  lines......: %s\n",
         get_overall_line($ln_found, $ln_hit, "line", "lines"))
        if ($ln_do);
    info("  functions..: %s\n",
         get_overall_line($fn_found, $fn_hit, "function", "functions"))
        if ($fn_do);
    info("  branches...: %s\n",
         get_overall_line($br_found, $br_hit, "branch", "branches"))
        if ($br_do);
}

sub get_fn_list($)
{
    my ($info) = @_;
    my %fns;
    my @result;

    foreach my $filename (keys(%{$info})) {
        my $data = $info->{$filename};
        my $funcdata = $data->{"func"};
        my $sumfnccount = $data->{"sumfnc"};

        if (defined($funcdata)) {
            foreach my $func_name (keys(%{$funcdata})) {
                $fns{$func_name} = 1;
            }
        }

        if (defined($sumfnccount)) {
            foreach my $func_name (keys(%{$sumfnccount})) {
                $fns{$func_name} = 1;
            }
        }
    }

    @result = keys(%fns);

    return \@result;
}

#
# rename_functions(info, conv)
#
# Rename all function names in INFO according to CONV: OLD_NAME -> NEW_NAME.
# In case two functions demangle to the same name, assume that they are
# different object code implementations for the same source function.
#

sub rename_functions($$)
{
    my ($info, $conv) = @_;

    foreach my $filename (keys(%{$info})) {
        my $data = $info->{$filename};
        my $funcdata;
        my $testfncdata;
        my $sumfnccount;
        my %newfuncdata;
        my %newsumfnccount;
        my $f_found;
        my $f_hit;

        # funcdata: function name -> line number
        $funcdata = $data->{"func"};
        foreach my $fn (keys(%{$funcdata})) {
            my $cn = $conv->{$fn};

            # Abort if two functions on different lines map to the
            # same demangled name.
            if (defined($newfuncdata{$cn}) &&
                $newfuncdata{$cn} != $funcdata->{$fn}) {
                die("ERROR: Demangled function name $fn ".
                    " maps to different lines (".
                    $newfuncdata{$cn}." vs ".
                    $funcdata->{$fn}.")\n");
            }
            $newfuncdata{$cn} = $funcdata->{$fn};
        }
        $data->{"func"} = \%newfuncdata;

        # testfncdata: test name -> testfnccount
        # testfnccount: function name -> execution count
        $testfncdata = $data->{"testfnc"};
        foreach my $tn (keys(%{$testfncdata})) {
            my $testfnccount = $testfncdata->{$tn};
            my %newtestfnccount;

            foreach my $fn (keys(%{$testfnccount})) {
                my $cn = $conv->{$fn};

                # Add counts for different functions that map
                # to the same name.
                $newtestfnccount{$cn} +=
                    $testfnccount->{$fn};
            }
            $testfncdata->{$tn} = \%newtestfnccount;
        }

        # sumfnccount: function name -> execution count
        $sumfnccount = $data->{"sumfnc"};
        foreach my $fn (keys(%{$sumfnccount})) {
            my $cn = $conv->{$fn};

            # Add counts for different functions that map
            # to the same name.
            $newsumfnccount{$cn} += $sumfnccount->{$fn};
        }
        $data->{"sumfnc"} = \%newsumfnccount;

        # Update function found and hit counts since they may have
        # changed
        $f_found = 0;
        $f_hit = 0;
        foreach my $fn (keys(%newsumfnccount)) {
            $f_found++;
            $f_hit++ if ($newsumfnccount{$fn} > 0);
        }
        $data->{"f_found"} = $f_found;
        $data->{"f_hit"} = $f_hit;
    }
}

#
# demangle_cpp(INFO)
#
# Demangle all function names found in INFO.
#
sub demangle_cpp($)
{
    my ($info) = @_;
    my $fn_list = get_fn_list($info);
    my @fn_list_demangled;
    my $tmpfile;
    my $handle;
    my %demangled;
    my $changed;

    # Nothing to do
    return if (!@$fn_list);

    # Write list to temp file
    (undef, $tmpfile) = tempfile();
    die("ERROR: could not create temporary file") if (!defined($tmpfile));
    open($handle, ">", $tmpfile) or
        die("ERROR: could not write to $tmpfile: $!\n");
    print($handle join("\n", @$fn_list));
    close($handle);

    # Run c++ filt on tempfile file and parse output, creating a hash
    # FR added -n to ignore underscore
    open($handle, "-|", "$cppfilt -n < $tmpfile") or
        die("ERROR: could not run c++filt: $!\n");
    @fn_list_demangled = <$handle>;
    close($handle);
    unlink($tmpfile) or
        warn("WARNING: could not remove temporary file $tmpfile: $!\n");

    if (scalar(@fn_list_demangled) != scalar(@$fn_list)) {
        die("ERROR: c++filt output not as expected (".
            scalar(@fn_list_demangled)." vs ".
            scalar(@$fn_list).") lines\n");
    }

    # Build old_name -> new_name
    $changed = 0;
    for (my $i = 0; $i < scalar(@$fn_list); $i++) {
        chomp($fn_list_demangled[$i]);
        $demangled{$fn_list->[$i]} = $fn_list_demangled[$i];
        $changed++ if ($fn_list->[$i] ne $fn_list_demangled[$i]);
    }

    info("Demangling $changed function names\n");

    # Change all occurrences of function names in INFO
    rename_functions($info, \%demangled);
}

#
# gen_html()
#
# Generate a set of HTML pages from contents of .info file INFO_FILENAME.
# Files will be written to the current directory. If provided, test case
# descriptions will be read from .tests file TEST_FILENAME and included
# in ouput.
#
# Die on error.
#

sub gen_html()
{
    local *HTML_HANDLE;
    my %overview;
    my %base_data;
    my $lines_found;
    my $lines_hit;
    my $fn_found;
    my $fn_hit;
    my $br_found;
    my $br_hit;
    my $overall_found = 0;
    my $overall_hit = 0;
    my $total_fn_found = 0;
    my $total_fn_hit = 0;
    my $total_br_found = 0;
    my $total_br_hit = 0;
    my $dir_name;
    my $link_name;
    my @dir_list;
    my %new_info;

    # Read in all specified .info files
    foreach (@info_filenames)
    {
        %new_info = %{read_info_file($_)};

        # Combine %new_info with %info_data
        %info_data = %{combine_info_files(\%info_data, \%new_info)};
    }

    info("Found %d entries.\n", scalar(keys(%info_data)));

    # Read and apply baseline data if specified
    if ($base_filename)
    {
        # Read baseline file
        info("Reading baseline file $base_filename\n");
        %base_data = %{read_info_file($base_filename)};
        info("Found %d entries.\n", scalar(keys(%base_data)));

        # Apply baseline
        info("Subtracting baseline data.\n");
        %info_data = %{apply_baseline(\%info_data, \%base_data)};
    }

    # Demangle C++ function names if requested
    demangle_cpp(\%info_data) if ($demangle_cpp);

    @dir_list = get_dir_list(keys(%info_data));
    @dir_list = uniq(\@dir_list);

    if ($no_prefix)
    {
        # User requested that we leave filenames alone
        info("User asked not to remove filename prefix\n");
    }
    elsif (!defined($dir_prefix))
    {
        # Get prefix common to most directories in list
        $dir_prefix = get_prefix(1, keys(%info_data));

        if ($dir_prefix)
        {
            info("Found common filename prefix \"$dir_prefix\"\n");
        }
        else
        {
            info("No common filename prefix found!\n");
            $no_prefix=1;
        }
    }
    else
    {
        info("Using user-specified filename prefix \"".
             "$dir_prefix\"\n");
        $dir_prefix =~ s/\/+$//;
        # FR ignore trailing backslash
        $dir_prefix =~ s/\\+$//;
    }

    $dir_prefix =~ s/\\/\//g;

    # Read in test description file if specified
    if ($desc_filename)
    {
        info("Reading test description file $desc_filename\n");
        %test_description = %{read_testfile($desc_filename)};

        # Remove test descriptions which are not referenced
        # from %info_data if user didn't tell us otherwise
        if (!$keep_descriptions)
        {
            remove_unused_descriptions();
        }
    }

    # Change to output directory if specified
    if ($output_directory)
    {
        chdir($output_directory)
            or die("ERROR: cannot change to directory ".
            "$output_directory!\n");
    }

    info("Writing .css and .png files.\n");
    write_css_file();
    write_png_files();

    if ($html_gzip)
    {
        info("Writing .htaccess file.\n");
        write_htaccess_file();
    }

    info("Generating output.\n");

    # Process each subdirectory and collect overview information
    foreach $dir_name (@dir_list)
    {
        ($lines_found, $lines_hit, $fn_found, $fn_hit,
         $br_found, $br_hit)
            = process_dir($dir_name);

        # Handle files in root directory gracefully
        $dir_name = "root" if ($dir_name eq "");

        # Remove prefix if applicable
        if (!$no_prefix && $dir_prefix)
        {
            # Match directory names beginning with $dir_prefix
            $dir_name = apply_prefix($dir_name, $dir_prefix);
        }

        # Generate name for directory overview HTML page
        if ($dir_name =~ /^\/(.*)$/)
        {
            $link_name = substr($dir_name, 1)."/index.$html_ext";
        }
        else
        {
            $link_name = $dir_name."/index.$html_ext";
        }

        $overview{$dir_name} = [$lines_found, $lines_hit, $fn_found,
                    $fn_hit, $br_found, $br_hit, $link_name,
                    get_rate($lines_found, $lines_hit),
                    get_rate($fn_found, $fn_hit),
                    get_rate($br_found, $br_hit)];
        $overall_found    += $lines_found;
        $overall_hit    += $lines_hit;
        $total_fn_found    += $fn_found;
        $total_fn_hit    += $fn_hit;
        $total_br_found    += $br_found;
        $total_br_hit    += $br_hit;
    }

    # Generate overview page
    info("Writing directory view page.\n");

    # Create sorted pages
    foreach (@fileview_sortlist) {
        write_dir_page($fileview_sortname[$_], ".", "", $test_title,
                   undef, $overall_found, $overall_hit,
                   $total_fn_found, $total_fn_hit, $total_br_found,
                   $total_br_hit, \%overview, {}, {}, {}, 0, $_);
    }

    # Check if there are any test case descriptions to write out
    if (%test_description)
    {
        info("Writing test case description file.\n");
        write_description_file( \%test_description,
                    $overall_found, $overall_hit,
                    $total_fn_found, $total_fn_hit,
                    $total_br_found, $total_br_hit);
    }

    print_overall_rate(1, $overall_found, $overall_hit,
               $func_coverage, $total_fn_found, $total_fn_hit,
               $br_coverage, $total_br_found, $total_br_hit);

    chdir($cwd);
}

#
# html_create(handle, filename)
#

sub html_create($$)
{
    my $handle = $_[0];
    my $filename = $_[1];

    if ($html_gzip)
    {
        open($handle, "|-", "gzip -c >'$filename'")
            or die("ERROR: cannot open $filename for writing ".
                   "(gzip)!\n");
    }
    else
    {
        open($handle, ">", $filename)
            or die("ERROR: cannot open $filename for writing!\n");
    }
}

sub write_dir_page($$$$$$$$$$$$$$$$$)
{
    my ($name, $rel_dir, $base_dir, $title, $trunc_dir, $overall_found,
        $overall_hit, $total_fn_found, $total_fn_hit, $total_br_found,
        $total_br_hit, $overview, $testhash, $testfnchash, $testbrhash,
        $view_type, $sort_type) = @_;

    # Generate directory overview page including details
    html_create(*HTML_HANDLE, "$rel_dir/index$name.$html_ext");
    if (!defined($trunc_dir)) {
        $trunc_dir = "";
    }
    $title .= " - " if ($trunc_dir ne "");
    write_html_prolog(*HTML_HANDLE, $base_dir, "LCOV - $title$trunc_dir");
    write_header(*HTML_HANDLE, $view_type, $trunc_dir, $rel_dir,
             $overall_found, $overall_hit, $total_fn_found,
             $total_fn_hit, $total_br_found, $total_br_hit, $sort_type);
    write_file_table(*HTML_HANDLE, $base_dir, $overview, $testhash,
             $testfnchash, $testbrhash, $view_type, $sort_type);
    write_html_epilog(*HTML_HANDLE, $base_dir);
    close(*HTML_HANDLE);
}


#
# process_dir(dir_name)
#

sub process_dir($)
{
    my $abs_dir = $_[0];
    my $trunc_dir;
    my $rel_dir = $abs_dir;
    my $base_dir;
    my $filename;
    my %overview;
    my $lines_found;
    my $lines_hit;
    my $fn_found;
    my $fn_hit;
    my $br_found;
    my $br_hit;
    my $overall_found=0;
    my $overall_hit=0;
    my $total_fn_found=0;
    my $total_fn_hit=0;
    my $total_br_found = 0;
    my $total_br_hit = 0;
    my $base_name;
    my $extension;
    my $testdata;
    my %testhash;
    my $testfncdata;
    my %testfnchash;
    my $testbrdata;
    my %testbrhash;
    my @sort_list;
    local *HTML_HANDLE;

    # Remove prefix if applicable
    if (!$no_prefix)
    {
        # Match directory name beginning with $dir_prefix
        $rel_dir = apply_prefix($rel_dir, $dir_prefix);
    }

    # FR Skip all mingw files
    if (!($rel_dir =~ m/mingw/))
    {

        $trunc_dir = $rel_dir;

        # Remove leading /
        if ($rel_dir =~ /^\/(.*)$/)
        {
            $rel_dir = substr($rel_dir, 1);
        }

        # Remove leading D:\
        if ($rel_dir =~ /^[a-zA-Z]:[\/|\\](.*)$/)
        {
            $rel_dir = substr($rel_dir, 3);
        }

        # Handle files in root directory gracefully
        $rel_dir = "root" if ($rel_dir eq "");
        $trunc_dir = "root" if ($trunc_dir eq "");

        $base_dir = get_relative_base_path($rel_dir);

        create_sub_dir($rel_dir);
        # Match filenames which specify files in this directory, not including
        # sub-directories
        foreach $filename (grep(/^\Q$abs_dir\E\/[^\/]*$/,keys(%info_data)))
        {
            my $page_link;
            my $func_link;

            ($lines_found, $lines_hit, $fn_found, $fn_hit, $br_found,
             $br_hit, $testdata, $testfncdata, $testbrdata) =
                process_file($trunc_dir, $rel_dir, $filename);

            $base_name = basename($filename);

            if ($no_sourceview) {
                $page_link = "";
            } elsif ($frames) {
                # Link to frameset page
                $page_link = "$base_name.gcov.frameset.$html_ext";
            } else {
                # Link directory to source code view page
                $page_link = "$base_name.gcov.$html_ext";
            }
            $overview{$base_name} = [$lines_found, $lines_hit, $fn_found,
                         $fn_hit, $br_found, $br_hit,
                         $page_link,
                         get_rate($lines_found, $lines_hit),
                         get_rate($fn_found, $fn_hit),
                         get_rate($br_found, $br_hit)];

            $testhash{$base_name} = $testdata;
            $testfnchash{$base_name} = $testfncdata;
            $testbrhash{$base_name} = $testbrdata;

            $overall_found    += $lines_found;
            $overall_hit    += $lines_hit;

            $total_fn_found += $fn_found;
            $total_fn_hit   += $fn_hit;

            $total_br_found += $br_found;
            $total_br_hit   += $br_hit;
        }

        # Create sorted pages
        foreach (@fileview_sortlist) {
            # Generate directory overview page (without details)
            write_dir_page($fileview_sortname[$_], $rel_dir, $base_dir,
                       $test_title, $trunc_dir, $overall_found,
                       $overall_hit, $total_fn_found, $total_fn_hit,
                       $total_br_found, $total_br_hit, \%overview, {},
                       {}, {}, 1, $_);
            if (!$show_details) {
                next;
            }
            # Generate directory overview page including details
            write_dir_page("-detail".$fileview_sortname[$_], $rel_dir,
                       $base_dir, $test_title, $trunc_dir,
                       $overall_found, $overall_hit, $total_fn_found,
                       $total_fn_hit, $total_br_found, $total_br_hit,
                       \%overview, \%testhash, \%testfnchash,
                       \%testbrhash, 1, $_);
        }

        # Calculate resulting line counts
    }
    else
    {
        info( "Skipping mingw!\n");
    }
    return ($overall_found, $overall_hit, $total_fn_found, $total_fn_hit, $total_br_found, $total_br_hit);
}


#
# get_converted_lines(testdata)
#
# Return hash of line numbers of those lines which were only covered in
# converted data sets.
#

sub get_converted_lines($)
{
    my $testdata = $_[0];
    my $testcount;
    my %converted;
    my %nonconverted;
    my $hash;
    my $testcase;
    my $line;
    my %result;


    # Get a hash containing line numbers with positive counts both for
    # converted and original data sets
    foreach $testcase (keys(%{$testdata}))
    {
        # Check to see if this is a converted data set
        if ($testcase =~ /,diff$/)
        {
            $hash = \%converted;
        }
        else
        {
            $hash = \%nonconverted;
        }

        $testcount = $testdata->{$testcase};
        # Add lines with a positive count to hash
        foreach $line (keys%{$testcount})
        {
            if ($testcount->{$line} > 0)
            {
                $hash->{$line} = 1;
            }
        }
    }

    # Combine both hashes to resulting list
    foreach $line (keys(%converted))
    {
        if (!defined($nonconverted{$line}))
        {
            $result{$line} = 1;
        }
    }

    return \%result;
}


sub write_function_page($$$$$$$$$$$$$$$$$$)
{
    my ($base_dir, $rel_dir, $trunc_dir, $base_name, $title,
        $lines_found, $lines_hit, $fn_found, $fn_hit, $br_found, $br_hit,
        $sumcount, $funcdata, $sumfnccount, $testfncdata, $sumbrcount,
        $testbrdata, $sort_type) = @_;
    my $pagetitle;
    my $filename;

    # Generate function table for this file
    if ($sort_type == 0) {
        $filename = "$rel_dir/$base_name.func.$html_ext";
    } else {
        $filename = "$rel_dir/$base_name.func-sort-c.$html_ext";
    }
    html_create(*HTML_HANDLE, $filename);
    $pagetitle = "LCOV - $title - $trunc_dir/$base_name - functions";
    write_html_prolog(*HTML_HANDLE, $base_dir, $pagetitle);
    write_header(*HTML_HANDLE, 4, "$trunc_dir/$base_name",
             "$rel_dir/$base_name", $lines_found, $lines_hit,
             $fn_found, $fn_hit, $br_found, $br_hit, $sort_type);
    write_function_table(*HTML_HANDLE, "$base_name.gcov.$html_ext",
                 $sumcount, $funcdata,
                 $sumfnccount, $testfncdata, $sumbrcount,
                 $testbrdata, $base_name,
                 $base_dir, $sort_type);
    write_html_epilog(*HTML_HANDLE, $base_dir, 1);
    close(*HTML_HANDLE);
}


#
# process_file(trunc_dir, rel_dir, filename)
#

sub process_file($$$)
{
    info("Processing file ".apply_prefix($_[2], $dir_prefix)."\n");

    my $trunc_dir = $_[0];
    my $rel_dir = $_[1];
    my $filename = $_[2];
    my $base_name = basename($filename);
    my $base_dir = get_relative_base_path($rel_dir);
    my $testdata;
    my $testcount;
    my $sumcount;
    my $funcdata;
    my $checkdata;
    my $testfncdata;
    my $sumfnccount;
    my $testbrdata;
    my $sumbrcount;
    my $lines_found;
    my $lines_hit;
    my $fn_found;
    my $fn_hit;
    my $br_found;
    my $br_hit;
    my $converted;
    my @source;
    my $pagetitle;
    local *HTML_HANDLE;

    ($testdata, $sumcount, $funcdata, $checkdata, $testfncdata,
     $sumfnccount, $testbrdata, $sumbrcount, $lines_found, $lines_hit,
     $fn_found, $fn_hit, $br_found, $br_hit)
        = get_info_entry($info_data{$filename});

    # Return after this point in case user asked us not to generate
    # source code view
    if ($no_sourceview)
    {
        return ($lines_found, $lines_hit, $fn_found, $fn_hit,
            $br_found, $br_hit, $testdata, $testfncdata,
            $testbrdata);
    }

    $converted = get_converted_lines($testdata);
    # Generate source code view for this file
    html_create(*HTML_HANDLE, "$rel_dir/$base_name.gcov.$html_ext");
    $pagetitle = "LCOV - $test_title - $trunc_dir/$base_name";
    write_html_prolog(*HTML_HANDLE, $base_dir, $pagetitle);
    write_header(*HTML_HANDLE, 2, "$trunc_dir/$base_name",
             "$rel_dir/$base_name", $lines_found, $lines_hit,
             $fn_found, $fn_hit, $br_found, $br_hit, 0);
    @source = write_source(*HTML_HANDLE, $filename, $sumcount, $checkdata,
                   $converted, $funcdata, $sumbrcount);

    write_html_epilog(*HTML_HANDLE, $base_dir, 1);
    close(*HTML_HANDLE);

    if ($func_coverage) {
        # Create function tables
        foreach (@funcview_sortlist) {
            write_function_page($base_dir, $rel_dir, $trunc_dir,
                        $base_name, $test_title,
                        $lines_found, $lines_hit,
                        $fn_found, $fn_hit, $br_found,
                        $br_hit, $sumcount,
                        $funcdata, $sumfnccount,
                        $testfncdata, $sumbrcount,
                        $testbrdata, $_);
        }
    }

    # Additional files are needed in case of frame output
    if (!$frames)
    {
        return ($lines_found, $lines_hit, $fn_found, $fn_hit,
            $br_found, $br_hit, $testdata, $testfncdata,
            $testbrdata);
    }

    # Create overview png file
    gen_png("$rel_dir/$base_name.gcov.png", $overview_width, $tab_size,
        @source);

    # Create frameset page
    html_create(*HTML_HANDLE,
            "$rel_dir/$base_name.gcov.frameset.$html_ext");
    write_frameset(*HTML_HANDLE, $base_dir, $base_name, $pagetitle);
    close(*HTML_HANDLE);

    # Write overview frame
    html_create(*HTML_HANDLE,
            "$rel_dir/$base_name.gcov.overview.$html_ext");
    write_overview(*HTML_HANDLE, $base_dir, $base_name, $pagetitle,
               scalar(@source));
    close(*HTML_HANDLE);

    return ($lines_found, $lines_hit, $fn_found, $fn_hit, $br_found,
        $br_hit, $testdata, $testfncdata, $testbrdata);
}


#
# read_info_file(info_filename)
#
# Read in the contents of the .info file specified by INFO_FILENAME. Data will
# be returned as a reference to a hash containing the following mappings:
#
# %result: for each filename found in file -> \%data
#
# %data: "test"  -> \%testdata
#        "sum"   -> \%sumcount
#        "func"  -> \%funcdata
#        "found" -> $lines_found (number of instrumented lines found in file)
#     "hit"   -> $lines_hit (number of executed lines in file)
#        "f_found" -> $fn_found (number of instrumented functions found in file)
#     "f_hit"   -> $fn_hit (number of executed functions in file)
#        "b_found" -> $br_found (number of instrumented branches found in file)
#     "b_hit"   -> $br_hit (number of executed branches in file)
#        "check" -> \%checkdata
#        "testfnc" -> \%testfncdata
#        "sumfnc"  -> \%sumfnccount
#        "testbr"  -> \%testbrdata
#        "sumbr"   -> \%sumbrcount
#
# %testdata   : name of test affecting this file -> \%testcount
# %testfncdata: name of test affecting this file -> \%testfnccount
# %testbrdata:  name of test affecting this file -> \%testbrcount
#
# %testcount   : line number   -> execution count for a single test
# %testfnccount: function name -> execution count for a single test
# %testbrcount : line number   -> branch coverage data for a single test
# %sumcount    : line number   -> execution count for all tests
# %sumfnccount : function name -> execution count for all tests
# %sumbrcount  : line number   -> branch coverage data for all tests
# %funcdata    : function name -> line number
# %checkdata   : line number   -> checksum of source code line
# $brdata      : vector of items: block, branch, taken
#
# Note that .info file sections referring to the same file and test name
# will automatically be combined by adding all execution counts.
#
# Note that if INFO_FILENAME ends with ".gz", it is assumed that the file
# is compressed using GZIP. If available, GUNZIP will be used to decompress
# this file.
#
# Die on error.
#

sub read_info_file($)
{
    my $tracefile = $_[0];        # Name of tracefile
    my %result;            # Resulting hash: file -> data
    my $data;            # Data handle for current entry
    my $testdata;            #       "             "
    my $testcount;            #       "             "
    my $sumcount;            #       "             "
    my $funcdata;            #       "             "
    my $checkdata;            #       "             "
    my $testfncdata;
    my $testfnccount;
    my $sumfnccount;
    my $testbrdata;
    my $testbrcount;
    my $sumbrcount;
    my $line;            # Current line read from .info file
    my $testname;            # Current test name
    my $filename;            # Current filename
    my $hitcount;            # Count for lines hit
    my $count;            # Execution count of current line
    my $negative;            # If set, warn about negative counts
    my $changed_testname;        # If set, warn about changed testname
    my $line_checksum;        # Checksum of current line
    my $br_found;
    my $br_hit;
    local *INFO_HANDLE;        # Filehandle for .info file

    info("Reading data file $tracefile\n");

    # Check if file exists and is readable
    stat($_[0]);
    if (!(-r _))
    {
        die("ERROR: cannot read file $_[0]!\n");
    }

    # Check if this is really a plain file
    if (!(-f _))
    {
        die("ERROR: not a plain file: $_[0]!\n");
    }

    # Check for .gz extension
    if ($_[0] =~ /\.gz$/)
    {
        # Check for availability of GZIP tool
        system_no_output(1, "gunzip" ,"-h")
            and die("ERROR: gunzip command not available!\n");

        # Check integrity of compressed file
        system_no_output(1, "gunzip", "-t", $_[0])
            and die("ERROR: integrity check failed for ".
                "compressed file $_[0]!\n");

        # Open compressed file
        open(INFO_HANDLE, "-|", "gunzip -c '$_[0]'")
            or die("ERROR: cannot start gunzip to decompress ".
                   "file $_[0]!\n");
    }
    else
    {
        # Open decompressed file
        open(INFO_HANDLE, "<", $_[0])
            or die("ERROR: cannot read file $_[0]!\n");
    }

    $testname = "";
    while (<INFO_HANDLE>)
    {
        chomp($_);
        $line = $_;

        # Switch statement
        foreach ($line)
        {
            /^TN:([^,]*)(,diff)?/ && do
            {
                # Test name information found
                $testname = defined($1) ? $1 : "";
                if ($testname =~ s/\W/_/g)
                {
                    $changed_testname = 1;
                }
                $testname .= $2 if (defined($2));
                last;
            };

            /^[SK]F:(.*)/ && do
            {
                # Filename information found
                # Retrieve data for new entry
                $filename = $1;

                $data = $result{$filename};
                ($testdata, $sumcount, $funcdata, $checkdata,
                 $testfncdata, $sumfnccount, $testbrdata,
                 $sumbrcount) =
                    get_info_entry($data);

                if (defined($testname))
                {
                    $testcount = $testdata->{$testname};
                    $testfnccount = $testfncdata->{$testname};
                    $testbrcount = $testbrdata->{$testname};
                }
                else
                {
                    $testcount = {};
                    $testfnccount = {};
                    $testbrcount = {};
                }
                last;
            };

            /^DA:(\d+),(-?\d+)(,[^,\s]+)?/ && do
            {
                # Fix negative counts
                $count = $2 < 0 ? 0 : $2;
                if ($2 < 0)
                {
                    $negative = 1;
                }
                # Execution count found, add to structure
                # Add summary counts
                $sumcount->{$1} += $count;

                # Add test-specific counts
                if (defined($testname))
                {
                    $testcount->{$1} += $count;
                }

                # Store line checksum if available
                if (defined($3))
                {
                    $line_checksum = substr($3, 1);

                    # Does it match a previous definition
                    if (defined($checkdata->{$1}) &&
                        ($checkdata->{$1} ne
                         $line_checksum))
                    {
                        die("ERROR: checksum mismatch ".
                            "at $filename:$1\n");
                    }

                    $checkdata->{$1} = $line_checksum;
                }
                last;
            };

            /^FN:(\d+),([^,]+)/ && do
            {
                last if (!$func_coverage);

                # Function data found, add to structure
                $funcdata->{$2} = $1;

                # Also initialize function call data
                if (!defined($sumfnccount->{$2})) {
                    $sumfnccount->{$2} = 0;
                }
                if (defined($testname))
                {
                    if (!defined($testfnccount->{$2})) {
                        $testfnccount->{$2} = 0;
                    }
                }
                last;
            };

            /^FNDA:(\d+),([^,]+)/ && do
            {
                last if (!$func_coverage);
                # Function call count found, add to structure
                # Add summary counts
                $sumfnccount->{$2} += $1;

                # Add test-specific counts
                if (defined($testname))
                {
                    $testfnccount->{$2} += $1;
                }
                last;
            };

            /^BRDA:(\d+),(\d+),(\d+),(\d+|-)/ && do {
                # Branch coverage data found
                my ($line, $block, $branch, $taken) =
                   ($1, $2, $3, $4);

                last if (!$br_coverage);
                $sumbrcount->{$line} =
                    br_ivec_push($sumbrcount->{$line},
                             $block, $branch, $taken);

                # Add test-specific counts
                if (defined($testname)) {
                    $testbrcount->{$line} =
                        br_ivec_push(
                            $testbrcount->{$line},
                            $block, $branch,
                            $taken);
                }
                last;
            };

            /^end_of_record/ && do
            {
                # Found end of section marker
                if ($filename)
                {
                    # Store current section data
                    if (defined($testname))
                    {
                        $testdata->{$testname} =
                            $testcount;
                        $testfncdata->{$testname} =
                            $testfnccount;
                        $testbrdata->{$testname} =
                            $testbrcount;
                    }

                    set_info_entry($data, $testdata,
                               $sumcount, $funcdata,
                               $checkdata, $testfncdata,
                               $sumfnccount,
                               $testbrdata,
                               $sumbrcount);
                    $result{$filename} = $data;
                    last;
                }
            };

            # default
            last;
        }
    }
    close(INFO_HANDLE);

    # Calculate lines_found and lines_hit for each file
    foreach $filename (keys(%result))
    {
        $data = $result{$filename};

        ($testdata, $sumcount, undef, undef, $testfncdata,
         $sumfnccount, $testbrdata, $sumbrcount) =
            get_info_entry($data);

        # Filter out empty files
        if (scalar(keys(%{$sumcount})) == 0)
        {
            delete($result{$filename});
            next;
        }
        # Filter out empty test cases
        foreach $testname (keys(%{$testdata}))
        {
            if (!defined($testdata->{$testname}) ||
                scalar(keys(%{$testdata->{$testname}})) == 0)
            {
                delete($testdata->{$testname});
                delete($testfncdata->{$testname});
            }
        }

        $data->{"found"} = scalar(keys(%{$sumcount}));
        $hitcount = 0;

        foreach (keys(%{$sumcount}))
        {
            if ($sumcount->{$_} > 0) { $hitcount++; }
        }

        $data->{"hit"} = $hitcount;

        # Get found/hit values for function call data
        $data->{"f_found"} = scalar(keys(%{$sumfnccount}));
        $hitcount = 0;

        foreach (keys(%{$sumfnccount})) {
            if ($sumfnccount->{$_} > 0) {
                $hitcount++;
            }
        }
        $data->{"f_hit"} = $hitcount;

        # Get found/hit values for branch data
        ($br_found, $br_hit) = get_br_found_and_hit($sumbrcount);

        $data->{"b_found"} = $br_found;
        $data->{"b_hit"} = $br_hit;
    }

    if (scalar(keys(%result)) == 0)
    {
        die("ERROR: no valid records found in tracefile $tracefile\n");
    }
    if ($negative)
    {
        warn("WARNING: negative counts found in tracefile ".
             "$tracefile\n");
    }
    if ($changed_testname)
    {
        warn("WARNING: invalid characters removed from testname in ".
             "tracefile $tracefile\n");
    }

    return(\%result);
}


#
# get_info_entry(hash_ref)
#
# Retrieve data from an entry of the structure generated by read_info_file().
# Return a list of references to hashes:
# (test data hash ref, sum count hash ref, funcdata hash ref, checkdata hash
#  ref, testfncdata hash ref, sumfnccount hash ref, lines found, lines hit,
#  functions found, functions hit)
#

sub get_info_entry($)
{
    my $testdata_ref = $_[0]->{"test"};
    my $sumcount_ref = $_[0]->{"sum"};
    my $funcdata_ref = $_[0]->{"func"};
    my $checkdata_ref = $_[0]->{"check"};
    my $testfncdata = $_[0]->{"testfnc"};
    my $sumfnccount = $_[0]->{"sumfnc"};
    my $testbrdata = $_[0]->{"testbr"};
    my $sumbrcount = $_[0]->{"sumbr"};
    my $lines_found = $_[0]->{"found"};
    my $lines_hit = $_[0]->{"hit"};
    my $fn_found = $_[0]->{"f_found"};
    my $fn_hit = $_[0]->{"f_hit"};
    my $br_found = $_[0]->{"b_found"};
    my $br_hit = $_[0]->{"b_hit"};

    return ($testdata_ref, $sumcount_ref, $funcdata_ref, $checkdata_ref,
        $testfncdata, $sumfnccount, $testbrdata, $sumbrcount,
        $lines_found, $lines_hit, $fn_found, $fn_hit,
        $br_found, $br_hit);
}


#
# set_info_entry(hash_ref, testdata_ref, sumcount_ref, funcdata_ref,
#                checkdata_ref, testfncdata_ref, sumfcncount_ref,
#                testbrdata_ref, sumbrcount_ref[,lines_found,
#                lines_hit, f_found, f_hit, $b_found, $b_hit])
#
# Update the hash referenced by HASH_REF with the provided data references.
#

sub set_info_entry($$$$$$$$$;$$$$$$)
{
    my $data_ref = $_[0];

    $data_ref->{"test"} = $_[1];
    $data_ref->{"sum"} = $_[2];
    $data_ref->{"func"} = $_[3];
    $data_ref->{"check"} = $_[4];
    $data_ref->{"testfnc"} = $_[5];
    $data_ref->{"sumfnc"} = $_[6];
    $data_ref->{"testbr"} = $_[7];
    $data_ref->{"sumbr"} = $_[8];

    if (defined($_[9])) { $data_ref->{"found"} = $_[9]; }
    if (defined($_[10])) { $data_ref->{"hit"} = $_[10]; }
    if (defined($_[11])) { $data_ref->{"f_found"} = $_[11]; }
    if (defined($_[12])) { $data_ref->{"f_hit"} = $_[12]; }
    if (defined($_[13])) { $data_ref->{"b_found"} = $_[13]; }
    if (defined($_[14])) { $data_ref->{"b_hit"} = $_[14]; }
}


#
# add_counts(data1_ref, data2_ref)
#
# DATA1_REF and DATA2_REF are references to hashes containing a mapping
#
#   line number -> execution count
#
# Return a list (RESULT_REF, LINES_FOUND, LINES_HIT) where RESULT_REF
# is a reference to a hash containing the combined mapping in which
# execution counts are added.
#

sub add_counts($$)
{
    my $data1_ref = $_[0];    # Hash 1
    my $data2_ref = $_[1];    # Hash 2
    my %result;        # Resulting hash
    my $line;        # Current line iteration scalar
    my $data1_count;    # Count of line in hash1
    my $data2_count;    # Count of line in hash2
    my $found = 0;        # Total number of lines found
    my $hit = 0;        # Number of lines with a count > 0

    foreach $line (keys(%$data1_ref))
    {
        $data1_count = $data1_ref->{$line};
        $data2_count = $data2_ref->{$line};

        # Add counts if present in both hashes
        if (defined($data2_count)) { $data1_count += $data2_count; }

        # Store sum in %result
        $result{$line} = $data1_count;

        $found++;
        if ($data1_count > 0) { $hit++; }
    }

    # Add lines unique to data2_ref
    foreach $line (keys(%$data2_ref))
    {
        # Skip lines already in data1_ref
        if (defined($data1_ref->{$line})) { next; }

        # Copy count from data2_ref
        $result{$line} = $data2_ref->{$line};

        $found++;
        if ($result{$line} > 0) { $hit++; }
    }

    return (\%result, $found, $hit);
}


#
# merge_checksums(ref1, ref2, filename)
#
# REF1 and REF2 are references to hashes containing a mapping
#
#   line number -> checksum
#
# Merge checksum lists defined in REF1 and REF2 and return reference to
# resulting hash. Die if a checksum for a line is defined in both hashes
# but does not match.
#

sub merge_checksums($$$)
{
    my $ref1 = $_[0];
    my $ref2 = $_[1];
    my $filename = $_[2];
    my %result;
    my $line;

    foreach $line (keys(%{$ref1}))
    {
        if (defined($ref2->{$line}) &&
            ($ref1->{$line} ne $ref2->{$line}))
        {
            die("ERROR: checksum mismatch at $filename:$line\n");
        }
        $result{$line} = $ref1->{$line};
    }

    foreach $line (keys(%{$ref2}))
    {
        $result{$line} = $ref2->{$line};
    }

    return \%result;
}


#
# merge_func_data(funcdata1, funcdata2, filename)
#

sub merge_func_data($$$)
{
    my ($funcdata1, $funcdata2, $filename) = @_;
    my %result;
    my $func;

    if (defined($funcdata1)) {
        %result = %{$funcdata1};
    }

    foreach $func (keys(%{$funcdata2})) {
        my $line1 = $result{$func};
        my $line2 = $funcdata2->{$func};

        if (defined($line1) && ($line1 != $line2)) {
            warn("WARNING: function data mismatch at ".
                 "$filename:$line2\n");
            next;
        }
        $result{$func} = $line2;
    }

    return \%result;
}


#
# add_fnccount(fnccount1, fnccount2)
#
# Add function call count data. Return list (fnccount_added, f_found, f_hit)
#

sub add_fnccount($$)
{
    my ($fnccount1, $fnccount2) = @_;
    my %result;
    my $fn_found;
    my $fn_hit;
    my $function;

    if (defined($fnccount1)) {
        %result = %{$fnccount1};
    }
    foreach $function (keys(%{$fnccount2})) {
        $result{$function} += $fnccount2->{$function};
    }
    $fn_found = scalar(keys(%result));
    $fn_hit = 0;
    foreach $function (keys(%result)) {
        if ($result{$function} > 0) {
            $fn_hit++;
        }
    }

    return (\%result, $fn_found, $fn_hit);
}

#
# add_testfncdata(testfncdata1, testfncdata2)
#
# Add function call count data for several tests. Return reference to
# added_testfncdata.
#

sub add_testfncdata($$)
{
    my ($testfncdata1, $testfncdata2) = @_;
    my %result;
    my $testname;

    foreach $testname (keys(%{$testfncdata1})) {
        if (defined($testfncdata2->{$testname})) {
            my $fnccount;

            # Function call count data for this testname exists
            # in both data sets: add
            ($fnccount) = add_fnccount(
                $testfncdata1->{$testname},
                $testfncdata2->{$testname});
            $result{$testname} = $fnccount;
            next;
        }
        # Function call count data for this testname is unique to
        # data set 1: copy
        $result{$testname} = $testfncdata1->{$testname};
    }

    # Add count data for testnames unique to data set 2
    foreach $testname (keys(%{$testfncdata2})) {
        if (!defined($result{$testname})) {
            $result{$testname} = $testfncdata2->{$testname};
        }
    }
    return \%result;
}


#
# brcount_to_db(brcount)
#
# Convert brcount data to the following format:
#
# db:          line number    -> block hash
# block hash:  block number   -> branch hash
# branch hash: branch number  -> taken value
#

sub brcount_to_db($)
{
    my ($brcount) = @_;
    my $line;
    my $db;

    # Add branches from first count to database
    foreach $line (keys(%{$brcount})) {
        my $brdata = $brcount->{$line};
        my $i;
        my $num = br_ivec_len($brdata);

        for ($i = 0; $i < $num; $i++) {
            my ($block, $branch, $taken) = br_ivec_get($brdata, $i);

            $db->{$line}->{$block}->{$branch} = $taken;
        }
    }

    return $db;
}


#
# db_to_brcount(db)
#
# Convert branch coverage data back to brcount format.
#

sub db_to_brcount($)
{
    my ($db) = @_;
    my $line;
    my $brcount = {};
    my $br_found = 0;
    my $br_hit = 0;

    # Convert database back to brcount format
    foreach $line (sort({$a <=> $b} keys(%{$db}))) {
        my $ldata = $db->{$line};
        my $brdata;
        my $block;

        foreach $block (sort({$a <=> $b} keys(%{$ldata}))) {
            my $bdata = $ldata->{$block};
            my $branch;

            foreach $branch (sort({$a <=> $b} keys(%{$bdata}))) {
                my $taken = $bdata->{$branch};

                $br_found++;
                $br_hit++ if ($taken ne "-" && $taken > 0);
                $brdata = br_ivec_push($brdata, $block,
                               $branch, $taken);
            }
        }
        $brcount->{$line} = $brdata;
    }

    return ($brcount, $br_found, $br_hit);
}


#
# combine_brcount(brcount1, brcount2, type)
#
# If add is BR_ADD, add branch coverage data and return list (brcount_added,
# br_found, br_hit). If add is BR_SUB, subtract the taken values of brcount2
# from brcount1 and return (brcount_sub, br_found, br_hit).
#

sub combine_brcount($$$)
{
    my ($brcount1, $brcount2, $type) = @_;
    my $line;
    my $block;
    my $branch;
    my $taken;
    my $db;
    my $br_found = 0;
    my $br_hit = 0;
    my $result;

    # Convert branches from first count to database
    $db = brcount_to_db($brcount1);
    # Combine values from database and second count
    foreach $line (keys(%{$brcount2})) {
        my $brdata = $brcount2->{$line};
        my $num = br_ivec_len($brdata);
        my $i;

        for ($i = 0; $i < $num; $i++) {
            ($block, $branch, $taken) = br_ivec_get($brdata, $i);
            my $new_taken = $db->{$line}->{$block}->{$branch};

            if ($type == $BR_ADD) {
                $new_taken = br_taken_add($new_taken, $taken);
            } elsif ($type == $BR_SUB) {
                $new_taken = br_taken_sub($new_taken, $taken);
            }
            $db->{$line}->{$block}->{$branch} = $new_taken
                if (defined($new_taken));
        }
    }
    # Convert database back to brcount format
    ($result, $br_found, $br_hit) = db_to_brcount($db);

    return ($result, $br_found, $br_hit);
}


#
# add_testbrdata(testbrdata1, testbrdata2)
#
# Add branch coverage data for several tests. Return reference to
# added_testbrdata.
#

sub add_testbrdata($$)
{
    my ($testbrdata1, $testbrdata2) = @_;
    my %result;
    my $testname;

    foreach $testname (keys(%{$testbrdata1})) {
        if (defined($testbrdata2->{$testname})) {
            my $brcount;

            # Branch coverage data for this testname exists
            # in both data sets: add
            ($brcount) = combine_brcount($testbrdata1->{$testname},
                     $testbrdata2->{$testname}, $BR_ADD);
            $result{$testname} = $brcount;
            next;
        }
        # Branch coverage data for this testname is unique to
        # data set 1: copy
        $result{$testname} = $testbrdata1->{$testname};
    }

    # Add count data for testnames unique to data set 2
    foreach $testname (keys(%{$testbrdata2})) {
        if (!defined($result{$testname})) {
            $result{$testname} = $testbrdata2->{$testname};
        }
    }
    return \%result;
}


#
# combine_info_entries(entry_ref1, entry_ref2, filename)
#
# Combine .info data entry hashes referenced by ENTRY_REF1 and ENTRY_REF2.
# Return reference to resulting hash.
#

sub combine_info_entries($$$)
{
    my $entry1 = $_[0];    # Reference to hash containing first entry
    my $testdata1;
    my $sumcount1;
    my $funcdata1;
    my $checkdata1;
    my $testfncdata1;
    my $sumfnccount1;
    my $testbrdata1;
    my $sumbrcount1;

    my $entry2 = $_[1];    # Reference to hash containing second entry
    my $testdata2;
    my $sumcount2;
    my $funcdata2;
    my $checkdata2;
    my $testfncdata2;
    my $sumfnccount2;
    my $testbrdata2;
    my $sumbrcount2;

    my %result;        # Hash containing combined entry
    my %result_testdata;
    my $result_sumcount = {};
    my $result_funcdata;
    my $result_testfncdata;
    my $result_sumfnccount;
    my $result_testbrdata;
    my $result_sumbrcount;
    my $lines_found;
    my $lines_hit;
    my $fn_found;
    my $fn_hit;
    my $br_found;
    my $br_hit;

    my $testname;
    my $filename = $_[2];

    # Retrieve data
    ($testdata1, $sumcount1, $funcdata1, $checkdata1, $testfncdata1,
     $sumfnccount1, $testbrdata1, $sumbrcount1) = get_info_entry($entry1);
    ($testdata2, $sumcount2, $funcdata2, $checkdata2, $testfncdata2,
     $sumfnccount2, $testbrdata2, $sumbrcount2) = get_info_entry($entry2);

    # Merge checksums
    $checkdata1 = merge_checksums($checkdata1, $checkdata2, $filename);

    # Combine funcdata
    $result_funcdata = merge_func_data($funcdata1, $funcdata2, $filename);

    # Combine function call count data
    $result_testfncdata = add_testfncdata($testfncdata1, $testfncdata2);
    ($result_sumfnccount, $fn_found, $fn_hit) =
        add_fnccount($sumfnccount1, $sumfnccount2);

    # Combine branch coverage data
    $result_testbrdata = add_testbrdata($testbrdata1, $testbrdata2);
    ($result_sumbrcount, $br_found, $br_hit) =
        combine_brcount($sumbrcount1, $sumbrcount2, $BR_ADD);

    # Combine testdata
    foreach $testname (keys(%{$testdata1}))
    {
        if (defined($testdata2->{$testname}))
        {
            # testname is present in both entries, requires
            # combination
            ($result_testdata{$testname}) =
                add_counts($testdata1->{$testname},
                       $testdata2->{$testname});
        }
        else
        {
            # testname only present in entry1, add to result
            $result_testdata{$testname} = $testdata1->{$testname};
        }

        # update sum count hash
        ($result_sumcount, $lines_found, $lines_hit) =
            add_counts($result_sumcount,
                   $result_testdata{$testname});
    }

    foreach $testname (keys(%{$testdata2}))
    {
        # Skip testnames already covered by previous iteration
        if (defined($testdata1->{$testname})) { next; }

        # testname only present in entry2, add to result hash
        $result_testdata{$testname} = $testdata2->{$testname};

        # update sum count hash
        ($result_sumcount, $lines_found, $lines_hit) =
            add_counts($result_sumcount,
                   $result_testdata{$testname});
    }

    # Calculate resulting sumcount

    # Store result
    set_info_entry(\%result, \%result_testdata, $result_sumcount,
               $result_funcdata, $checkdata1, $result_testfncdata,
               $result_sumfnccount, $result_testbrdata,
               $result_sumbrcount, $lines_found, $lines_hit,
               $fn_found, $fn_hit, $br_found, $br_hit);

    return(\%result);
}


#
# combine_info_files(info_ref1, info_ref2)
#
# Combine .info data in hashes referenced by INFO_REF1 and INFO_REF2. Return
# reference to resulting hash.
#

sub combine_info_files($$)
{
    my %hash1 = %{$_[0]};
    my %hash2 = %{$_[1]};
    my $filename;

    foreach $filename (keys(%hash2))
    {
        if ($hash1{$filename})
        {
            # Entry already exists in hash1, combine them
            $hash1{$filename} =
                combine_info_entries($hash1{$filename},
                             $hash2{$filename},
                             $filename);
        }
        else
        {
            # Entry is unique in both hashes, simply add to
            # resulting hash
            $hash1{$filename} = $hash2{$filename};
        }
    }

    return(\%hash1);
}


#
# get_prefix(min_dir, filename_list)
#
# Search FILENAME_LIST for a directory prefix which is common to as many
# list entries as possible, so that removing this prefix will minimize the
# sum of the lengths of all resulting shortened filenames while observing
# that no filename has less than MIN_DIR parent directories.
#

sub get_prefix($@)
{
    my ($min_dir, @filename_list) = @_;
    my %prefix;            # mapping: prefix -> sum of lengths
    my $current;            # Temporary iteration variable

    # Find list of prefixes
    foreach (@filename_list)
    {
        # Need explicit assignment to get a copy of $_ so that
        # shortening the contained prefix does not affect the list
        $current = $_;
        while ($current = shorten_prefix($current))
        {
            $current .= "/";

            # Skip rest if the remaining prefix has already been
            # added to hash
            if (exists($prefix{$current})) { last; }

            # Initialize with 0
            $prefix{$current}="0";
        }

    }

    # Remove all prefixes that would cause filenames to have less than
    # the minimum number of parent directories
    foreach my $filename (@filename_list) {
        my $dir = dirname($filename);

        for (my $i = 0; $i < $min_dir; $i++) {
            delete($prefix{$dir."/"});
            $dir = shorten_prefix($dir);
        }
    }

    # Check if any prefix remains
    return undef if (!%prefix);

    # Calculate sum of lengths for all prefixes
    foreach $current (keys(%prefix))
    {
        foreach (@filename_list)
        {
            # Add original length
            $prefix{$current} += length($_);

            # Check whether prefix matches
            if (substr($_, 0, length($current)) eq $current)
            {
                # Subtract prefix length for this filename
                $prefix{$current} -= length($current);
            }
        }
    }

    # Find and return prefix with minimal sum
    $current = (keys(%prefix))[0];

    foreach (keys(%prefix))
    {
        if ($prefix{$_} < $prefix{$current})
        {
            $current = $_;
        }
    }

    $current =~ s/\/$//;

    return($current);
}


#
# shorten_prefix(prefix)
#
# Return PREFIX shortened by last directory component.
#

sub shorten_prefix($)
{
    my @list = split("/", $_[0]);

    pop(@list);
    return join("/", @list);
}



#
# get_dir_list(filename_list)
#
# Return sorted list of directories for each entry in given FILENAME_LIST.
#

sub get_dir_list(@)
{
    my %result;

    foreach (@_)
    {
        $result{shorten_prefix($_)} = "";
    }

    return(sort(keys(%result)));
}


#
# get_relative_base_path(subdirectory)
#
# Return a relative path string which references the base path when applied
# in SUBDIRECTORY.
#
# Example: get_relative_base_path("fs/mm") -> "../../"
#

sub get_relative_base_path($)
{
    my $result = "";
    my $index;

    # Make an empty directory path a special case
    if (!$_[0]) { return(""); }

    # Count number of /s in path
    $index = ($_[0] =~ s/\//\//g);

    # Add a ../ to $result for each / in the directory path + 1
    for (; $index>=0; $index--)
    {
        $result .= "../";
    }

    return $result;
}


#
# read_testfile(test_filename)
#
# Read in file TEST_FILENAME which contains test descriptions in the format:
#
#   TN:<whitespace><test name>
#   TD:<whitespace><test description>
#
# for each test case. Return a reference to a hash containing a mapping
#
#   test name -> test description.
#
# Die on error.
#

sub read_testfile($)
{
    my %result;
    my $test_name;
    my $changed_testname;
    local *TEST_HANDLE;

    open(TEST_HANDLE, "<", $_[0])
        or die("ERROR: cannot open $_[0]!\n");

    while (<TEST_HANDLE>)
    {
        chomp($_);

        # Match lines beginning with TN:<whitespace(s)>
        if (/^TN:\s+(.*?)\s*$/)
        {
            # Store name for later use
            $test_name = $1;
            if ($test_name =~ s/\W/_/g)
            {
                $changed_testname = 1;
            }
        }

        # Match lines beginning with TD:<whitespace(s)>
        if (/^TD:\s+(.*?)\s*$/)
        {
            if (!defined($test_name)) {
                die("ERROR: Found test description without prior test name in $_[0]:$.\n");
            }
            # Check for empty line
            if ($1)
            {
                # Add description to hash
                $result{$test_name} .= " $1";
            }
            else
            {
                # Add empty line
                $result{$test_name} .= "\n\n";
            }
        }
    }

    close(TEST_HANDLE);

    if ($changed_testname)
    {
        warn("WARNING: invalid characters removed from testname in ".
             "descriptions file $_[0]\n");
    }

    return \%result;
}


#
# escape_html(STRING)
#
# Return a copy of STRING in which all occurrences of HTML special characters
# are escaped.
#

sub escape_html($)
{
    my $string = $_[0];

    if (!$string) { return ""; }

    $string =~ s/&/&amp;/g;        # & -> &amp;
    $string =~ s/</&lt;/g;        # < -> &lt;
    $string =~ s/>/&gt;/g;        # > -> &gt;
    $string =~ s/\"/&quot;/g;    # " -> &quot;

    while ($string =~ /^([^\t]*)(\t)/)
    {
        my $replacement = " "x($tab_size - (length($1) % $tab_size));
        $string =~ s/^([^\t]*)(\t)/$1$replacement/;
    }

    $string =~ s/\n/<br>/g;        # \n -> <br>

    return $string;
}


#
# get_date_string()
#
# Return the current date in the form: yyyy-mm-dd
#

sub get_date_string()
{
    my $year;
    my $month;
    my $day;
    my $hour;
    my $min;
    my $sec;

    ($year, $month, $day, $hour, $min, $sec) =
        (localtime())[5, 4, 3, 2, 1, 0];

    return sprintf("%d-%02d-%02d %02d:%02d:%02d", $year+1900, $month+1,
               $day, $hour, $min, $sec);
}


#
# create_sub_dir(dir_name)
#
# Create subdirectory DIR_NAME if it does not already exist, including all its
# parent directories.
#
# Die on error.
#

sub create_sub_dir($)
{
    my ($dir) = @_;

    system("mkdir", "-p" ,$dir)
        and die("ERROR: cannot create directory $dir!\n");
}


#
# write_description_file(descriptions, overall_found, overall_hit,
#                        total_fn_found, total_fn_hit, total_br_found,
#                        total_br_hit)
#
# Write HTML file containing all test case descriptions. DESCRIPTIONS is a
# reference to a hash containing a mapping
#
#   test case name -> test case description
#
# Die on error.
#

sub write_description_file($$$$$$$)
{
    my %description = %{$_[0]};
    my $found = $_[1];
    my $hit = $_[2];
    my $fn_found = $_[3];
    my $fn_hit = $_[4];
    my $br_found = $_[5];
    my $br_hit = $_[6];
    my $test_name;
    local *HTML_HANDLE;

    html_create(*HTML_HANDLE,"descriptions.$html_ext");
    write_html_prolog(*HTML_HANDLE, "", "LCOV - test case descriptions");
    write_header(*HTML_HANDLE, 3, "", "", $found, $hit, $fn_found,
             $fn_hit, $br_found, $br_hit, 0);

    write_test_table_prolog(*HTML_HANDLE,
             "Test case descriptions - alphabetical list");

    foreach $test_name (sort(keys(%description)))
    {
        my $desc = $description{$test_name};

        $desc = escape_html($desc) if (!$rc_desc_html);
        write_test_table_entry(*HTML_HANDLE, $test_name, $desc);
    }

    write_test_table_epilog(*HTML_HANDLE);
    write_html_epilog(*HTML_HANDLE, "");

    close(*HTML_HANDLE);
}



#
# write_png_files()
#
# Create all necessary .png files for the HTML-output in the current
# directory. .png-files are used as bar graphs.
#
# Die on error.
#

sub write_png_files()
{
    my %data;
    local *PNG_HANDLE;

    $data{"ruby.png"} =
        [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00,
         0x00, 0x0d, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01,
         0x00, 0x00, 0x00, 0x01, 0x01, 0x03, 0x00, 0x00, 0x00, 0x25,
         0xdb, 0x56, 0xca, 0x00, 0x00, 0x00, 0x07, 0x74, 0x49, 0x4d,
         0x45, 0x07, 0xd2, 0x07, 0x11, 0x0f, 0x18, 0x10, 0x5d, 0x57,
         0x34, 0x6e, 0x00, 0x00, 0x00, 0x09, 0x70, 0x48, 0x59, 0x73,
         0x00, 0x00, 0x0b, 0x12, 0x00, 0x00, 0x0b, 0x12, 0x01, 0xd2,
         0xdd, 0x7e, 0xfc, 0x00, 0x00, 0x00, 0x04, 0x67, 0x41, 0x4d,
         0x41, 0x00, 0x00, 0xb1, 0x8f, 0x0b, 0xfc, 0x61, 0x05, 0x00,
         0x00, 0x00, 0x06, 0x50, 0x4c, 0x54, 0x45, 0xff, 0x35, 0x2f,
         0x00, 0x00, 0x00, 0xd0, 0x33, 0x9a, 0x9d, 0x00, 0x00, 0x00,
         0x0a, 0x49, 0x44, 0x41, 0x54, 0x78, 0xda, 0x63, 0x60, 0x00,
         0x00, 0x00, 0x02, 0x00, 0x01, 0xe5, 0x27, 0xde, 0xfc, 0x00,
         0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60,
         0x82];
    $data{"amber.png"} =
        [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00,
         0x00, 0x0d, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01,
         0x00, 0x00, 0x00, 0x01, 0x01, 0x03, 0x00, 0x00, 0x00, 0x25,
         0xdb, 0x56, 0xca, 0x00, 0x00, 0x00, 0x07, 0x74, 0x49, 0x4d,
         0x45, 0x07, 0xd2, 0x07, 0x11, 0x0f, 0x28, 0x04, 0x98, 0xcb,
         0xd6, 0xe0, 0x00, 0x00, 0x00, 0x09, 0x70, 0x48, 0x59, 0x73,
         0x00, 0x00, 0x0b, 0x12, 0x00, 0x00, 0x0b, 0x12, 0x01, 0xd2,
         0xdd, 0x7e, 0xfc, 0x00, 0x00, 0x00, 0x04, 0x67, 0x41, 0x4d,
         0x41, 0x00, 0x00, 0xb1, 0x8f, 0x0b, 0xfc, 0x61, 0x05, 0x00,
         0x00, 0x00, 0x06, 0x50, 0x4c, 0x54, 0x45, 0xff, 0xe0, 0x50,
         0x00, 0x00, 0x00, 0xa2, 0x7a, 0xda, 0x7e, 0x00, 0x00, 0x00,
         0x0a, 0x49, 0x44, 0x41, 0x54, 0x78, 0xda, 0x63, 0x60, 0x00,
           0x00, 0x00, 0x02, 0x00, 0x01, 0xe5, 0x27, 0xde, 0xfc, 0x00,
         0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60,
         0x82];
    $data{"emerald.png"} =
        [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00,
         0x00, 0x0d, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01,
         0x00, 0x00, 0x00, 0x01, 0x01, 0x03, 0x00, 0x00, 0x00, 0x25,
         0xdb, 0x56, 0xca, 0x00, 0x00, 0x00, 0x07, 0x74, 0x49, 0x4d,
         0x45, 0x07, 0xd2, 0x07, 0x11, 0x0f, 0x22, 0x2b, 0xc9, 0xf5,
         0x03, 0x33, 0x00, 0x00, 0x00, 0x09, 0x70, 0x48, 0x59, 0x73,
         0x00, 0x00, 0x0b, 0x12, 0x00, 0x00, 0x0b, 0x12, 0x01, 0xd2,
         0xdd, 0x7e, 0xfc, 0x00, 0x00, 0x00, 0x04, 0x67, 0x41, 0x4d,
         0x41, 0x00, 0x00, 0xb1, 0x8f, 0x0b, 0xfc, 0x61, 0x05, 0x00,
         0x00, 0x00, 0x06, 0x50, 0x4c, 0x54, 0x45, 0x1b, 0xea, 0x59,
         0x0a, 0x0a, 0x0a, 0x0f, 0xba, 0x50, 0x83, 0x00, 0x00, 0x00,
         0x0a, 0x49, 0x44, 0x41, 0x54, 0x78, 0xda, 0x63, 0x60, 0x00,
         0x00, 0x00, 0x02, 0x00, 0x01, 0xe5, 0x27, 0xde, 0xfc, 0x00,
         0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60,
         0x82];
    $data{"snow.png"} =
        [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00,
         0x00, 0x0d, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01,
         0x00, 0x00, 0x00, 0x01, 0x01, 0x03, 0x00, 0x00, 0x00, 0x25,
         0xdb, 0x56, 0xca, 0x00, 0x00, 0x00, 0x07, 0x74, 0x49, 0x4d,
         0x45, 0x07, 0xd2, 0x07, 0x11, 0x0f, 0x1e, 0x1d, 0x75, 0xbc,
         0xef, 0x55, 0x00, 0x00, 0x00, 0x09, 0x70, 0x48, 0x59, 0x73,
         0x00, 0x00, 0x0b, 0x12, 0x00, 0x00, 0x0b, 0x12, 0x01, 0xd2,
         0xdd, 0x7e, 0xfc, 0x00, 0x00, 0x00, 0x04, 0x67, 0x41, 0x4d,
         0x41, 0x00, 0x00, 0xb1, 0x8f, 0x0b, 0xfc, 0x61, 0x05, 0x00,
         0x00, 0x00, 0x06, 0x50, 0x4c, 0x54, 0x45, 0xff, 0xff, 0xff,
         0x00, 0x00, 0x00, 0x55, 0xc2, 0xd3, 0x7e, 0x00, 0x00, 0x00,
         0x0a, 0x49, 0x44, 0x41, 0x54, 0x78, 0xda, 0x63, 0x60, 0x00,
         0x00, 0x00, 0x02, 0x00, 0x01, 0xe5, 0x27, 0xde, 0xfc, 0x00,
         0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60,
         0x82];
    $data{"glass.png"} =
        [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00,
         0x00, 0x0d, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01,
         0x00, 0x00, 0x00, 0x01, 0x01, 0x03, 0x00, 0x00, 0x00, 0x25,
         0xdb, 0x56, 0xca, 0x00, 0x00, 0x00, 0x04, 0x67, 0x41, 0x4d,
         0x41, 0x00, 0x00, 0xb1, 0x8f, 0x0b, 0xfc, 0x61, 0x05, 0x00,
         0x00, 0x00, 0x06, 0x50, 0x4c, 0x54, 0x45, 0xff, 0xff, 0xff,
         0x00, 0x00, 0x00, 0x55, 0xc2, 0xd3, 0x7e, 0x00, 0x00, 0x00,
         0x01, 0x74, 0x52, 0x4e, 0x53, 0x00, 0x40, 0xe6, 0xd8, 0x66,
         0x00, 0x00, 0x00, 0x01, 0x62, 0x4b, 0x47, 0x44, 0x00, 0x88,
         0x05, 0x1d, 0x48, 0x00, 0x00, 0x00, 0x09, 0x70, 0x48, 0x59,
         0x73, 0x00, 0x00, 0x0b, 0x12, 0x00, 0x00, 0x0b, 0x12, 0x01,
         0xd2, 0xdd, 0x7e, 0xfc, 0x00, 0x00, 0x00, 0x07, 0x74, 0x49,
         0x4d, 0x45, 0x07, 0xd2, 0x07, 0x13, 0x0f, 0x08, 0x19, 0xc4,
         0x40, 0x56, 0x10, 0x00, 0x00, 0x00, 0x0a, 0x49, 0x44, 0x41,
         0x54, 0x78, 0x9c, 0x63, 0x60, 0x00, 0x00, 0x00, 0x02, 0x00,
         0x01, 0x48, 0xaf, 0xa4, 0x71, 0x00, 0x00, 0x00, 0x00, 0x49,
         0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82];
    $data{"updown.png"} =
        [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00,
         0x00, 0x0d, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x0a,
         0x00, 0x00, 0x00, 0x0e, 0x08, 0x06, 0x00, 0x00, 0x00, 0x16,
         0xa3, 0x8d, 0xab, 0x00, 0x00, 0x00, 0x3c, 0x49, 0x44, 0x41,
         0x54, 0x28, 0xcf, 0x63, 0x60, 0x40, 0x03, 0xff, 0xa1, 0x00,
         0x5d, 0x9c, 0x11, 0x5d, 0x11, 0x8a, 0x24, 0x23, 0x23, 0x23,
         0x86, 0x42, 0x6c, 0xa6, 0x20, 0x2b, 0x66, 0xc4, 0xa7, 0x08,
         0x59, 0x31, 0x23, 0x21, 0x45, 0x30, 0xc0, 0xc4, 0x30, 0x60,
         0x80, 0xfa, 0x6e, 0x24, 0x3e, 0x78, 0x48, 0x0a, 0x70, 0x62,
         0xa2, 0x90, 0x81, 0xd8, 0x44, 0x01, 0x00, 0xe9, 0x5c, 0x2f,
         0xf5, 0xe2, 0x9d, 0x0f, 0xf9, 0x00, 0x00, 0x00, 0x00, 0x49,
         0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82] if ($sort);
    foreach (keys(%data))
    {
        open(PNG_HANDLE, ">", $_)
            or die("ERROR: cannot create $_!\n");
        binmode(PNG_HANDLE);
        print(PNG_HANDLE map(chr,@{$data{$_}}));
        close(PNG_HANDLE);
    }
}


#
# write_htaccess_file()
#

sub write_htaccess_file()
{
    local *HTACCESS_HANDLE;
    my $htaccess_data;

    open(*HTACCESS_HANDLE, ">", ".htaccess")
        or die("ERROR: cannot open .htaccess for writing!\n");

    $htaccess_data = (<<"END_OF_HTACCESS")
AddEncoding x-gzip .html
END_OF_HTACCESS
    ;

    print(HTACCESS_HANDLE $htaccess_data);
    close(*HTACCESS_HANDLE);
}


#
# write_css_file()
#
# Write the cascading style sheet file gcov.css to the current directory.
# This file defines basic layout attributes of all generated HTML pages.
#

sub write_css_file()
{
    local *CSS_HANDLE;

    # Check for a specified external style sheet file
    if ($css_filename)
    {
        # Simply copy that file
        system("cp", $css_filename, "gcov.css")
            and die("ERROR: cannot copy file $css_filename!\n");
        return;
    }

    open(CSS_HANDLE, ">", "gcov.css")
        or die ("ERROR: cannot open gcov.css for writing!\n");


    # *************************************************************

    my $css_data = ($_=<<"END_OF_CSS")
    /* All views: initial background and text color */
    body
    {
      color: #000000;
      background-color: #FFFFFF;
    }

    /* All views: standard link format*/
    a:link
    {
      color: #284FA8;
      text-decoration: underline;
    }

    /* All views: standard link - visited format */
    a:visited
    {
      color: #00CB40;
      text-decoration: underline;
    }

    /* All views: standard link - activated format */
    a:active
    {
      color: #FF0040;
      text-decoration: underline;
    }

    /* All views: main title format */
    td.title
    {
      text-align: center;
      padding-bottom: 10px;
      font-family: sans-serif;
      font-size: 20pt;
      font-style: italic;
      font-weight: bold;
    }

    /* All views: header item format */
    td.headerItem
    {
      text-align: right;
      padding-right: 6px;
      font-family: sans-serif;
      font-weight: bold;
      vertical-align: top;
      white-space: nowrap;
    }

    /* All views: header item value format */
    td.headerValue
    {
      text-align: left;
      color: #284FA8;
      font-family: sans-serif;
      font-weight: bold;
      white-space: nowrap;
    }

    /* All views: header item coverage table heading */
    td.headerCovTableHead
    {
      text-align: center;
      padding-right: 6px;
      padding-left: 6px;
      padding-bottom: 0px;
      font-family: sans-serif;
      font-size: 80%;
      white-space: nowrap;
    }

    /* All views: header item coverage table entry */
    td.headerCovTableEntry
    {
      text-align: right;
      color: #284FA8;
      font-family: sans-serif;
      font-weight: bold;
      white-space: nowrap;
      padding-left: 12px;
      padding-right: 4px;
      background-color: #DAE7FE;
    }

    /* All views: header item coverage table entry for high coverage rate */
    td.headerCovTableEntryHi
    {
      text-align: right;
      color: #000000;
      font-family: sans-serif;
      font-weight: bold;
      white-space: nowrap;
      padding-left: 12px;
      padding-right: 4px;
      background-color: #A7FC9D;
    }

    /* All views: header item coverage table entry for medium coverage rate */
    td.headerCovTableEntryMed
    {
      text-align: right;
      color: #000000;
      font-family: sans-serif;
      font-weight: bold;
      white-space: nowrap;
      padding-left: 12px;
      padding-right: 4px;
      background-color: #FFEA20;
    }

    /* All views: header item coverage table entry for ow coverage rate */
    td.headerCovTableEntryLo
    {
      text-align: right;
      color: #000000;
      font-family: sans-serif;
      font-weight: bold;
      white-space: nowrap;
      padding-left: 12px;
      padding-right: 4px;
      background-color: #FF0000;
    }

    /* All views: header legend value for legend entry */
    td.headerValueLeg
    {
      text-align: left;
      color: #000000;
      font-family: sans-serif;
      font-size: 80%;
      white-space: nowrap;
      padding-top: 4px;
    }

    /* All views: color of horizontal ruler */
    td.ruler
    {
      background-color: #6688D4;
    }

    /* All views: version string format */
    td.versionInfo
    {
      text-align: center;
      padding-top: 2px;
      font-family: sans-serif;
      font-style: italic;
    }

    /* Directory view/File view (all)/Test case descriptions:
       table headline format */
    td.tableHead
    {
      text-align: center;
      color: #FFFFFF;
      background-color: #6688D4;
      font-family: sans-serif;
      font-size: 120%;
      font-weight: bold;
      white-space: nowrap;
      padding-left: 4px;
      padding-right: 4px;
    }

    span.tableHeadSort
    {
      padding-right: 4px;
    }

    /* Directory view/File view (all): filename entry format */
    td.coverFile
    {
      text-align: left;
      padding-left: 10px;
      padding-right: 20px;
      color: #284FA8;
      background-color: #DAE7FE;
      font-family: monospace;
    }

    /* Directory view/File view (all): bar-graph entry format*/
    td.coverBar
    {
      padding-left: 10px;
      padding-right: 10px;
      background-color: #DAE7FE;
    }

    /* Directory view/File view (all): bar-graph outline color */
    td.coverBarOutline
    {
      background-color: #000000;
    }

    /* Directory view/File view (all): percentage entry for files with
       high coverage rate */
    td.coverPerHi
    {
      text-align: right;
      padding-left: 10px;
      padding-right: 10px;
      background-color: #A7FC9D;
      font-weight: bold;
      font-family: sans-serif;
    }

    /* Directory view/File view (all): line count entry for files with
       high coverage rate */
    td.coverNumHi
    {
      text-align: right;
      padding-left: 10px;
      padding-right: 10px;
      background-color: #A7FC9D;
      white-space: nowrap;
      font-family: sans-serif;
    }

    /* Directory view/File view (all): percentage entry for files with
       medium coverage rate */
    td.coverPerMed
    {
      text-align: right;
      padding-left: 10px;
      padding-right: 10px;
      background-color: #FFEA20;
      font-weight: bold;
      font-family: sans-serif;
    }

    /* Directory view/File view (all): line count entry for files with
       medium coverage rate */
    td.coverNumMed
    {
      text-align: right;
      padding-left: 10px;
      padding-right: 10px;
      background-color: #FFEA20;
      white-space: nowrap;
      font-family: sans-serif;
    }

    /* Directory view/File view (all): percentage entry for files with
       low coverage rate */
    td.coverPerLo
    {
      text-align: right;
      padding-left: 10px;
      padding-right: 10px;
      background-color: #FF0000;
      font-weight: bold;
      font-family: sans-serif;
    }

    /* Directory view/File view (all): line count entry for files with
       low coverage rate */
    td.coverNumLo
    {
      text-align: right;
      padding-left: 10px;
      padding-right: 10px;
      background-color: #FF0000;
      white-space: nowrap;
      font-family: sans-serif;
    }

    /* File view (all): "show/hide details" link format */
    a.detail:link
    {
      color: #B8D0FF;
      font-size:80%;
    }

    /* File view (all): "show/hide details" link - visited format */
    a.detail:visited
    {
      color: #B8D0FF;
      font-size:80%;
    }

    /* File view (all): "show/hide details" link - activated format */
    a.detail:active
    {
      color: #FFFFFF;
      font-size:80%;
    }

    /* File view (detail): test name entry */
    td.testName
    {
      text-align: right;
      padding-right: 10px;
      background-color: #DAE7FE;
      font-family: sans-serif;
    }

    /* File view (detail): test percentage entry */
    td.testPer
    {
      text-align: right;
      padding-left: 10px;
      padding-right: 10px;
      background-color: #DAE7FE;
      font-family: sans-serif;
    }

    /* File view (detail): test lines count entry */
    td.testNum
    {
      text-align: right;
      padding-left: 10px;
      padding-right: 10px;
      background-color: #DAE7FE;
      font-family: sans-serif;
    }

    /* Test case descriptions: test name format*/
    dt
    {
      font-family: sans-serif;
      font-weight: bold;
    }

    /* Test case descriptions: description table body */
    td.testDescription
    {
      padding-top: 10px;
      padding-left: 30px;
      padding-bottom: 10px;
      padding-right: 30px;
      background-color: #DAE7FE;
    }

    /* Source code view: function entry */
    td.coverFn
    {
      text-align: left;
      padding-left: 10px;
      padding-right: 20px;
      color: #284FA8;
      background-color: #DAE7FE;
      font-family: monospace;
    }

    /* Source code view: function entry zero count*/
    td.coverFnLo
    {
      text-align: right;
      padding-left: 10px;
      padding-right: 10px;
      background-color: #FF6230;
      font-weight: bold;
      font-family: sans-serif;
    }

    /* Source code view: function entry nonzero count*/
    td.coverFnHi
    {
      text-align: right;
      padding-left: 10px;
      padding-right: 10px;
      background-color: #66FF66;
      font-weight: bold;
      font-family: sans-serif;
    }

    /* Source code view: source code format */
    pre.source
    {
      font-family: monospace;
      white-space: pre;
      margin-top: 2px;
    }

    /* Source code view: line number format */
    span.lineNum
    {
      background-color: #EFE383;
    }

    /* Source code view: format for lines which were executed */
    td.lineCov,
    span.lineCov
    {
      background-color: #66FF66;
    }

    /* Source code view: format for Cov legend */
    span.coverLegendCov
    {
      padding-left: 10px;
      padding-right: 10px;
      padding-bottom: 2px;
      background-color: #CAD7FE;
    }

    /* Source code view: format for lines which were not executed */
    td.lineNoCov,
    span.lineNoCov
    {
      background-color: #FF6230;
    }

    /* Source code view: format for NoCov legend */
    span.coverLegendNoCov
    {
      padding-left: 10px;
      padding-right: 10px;
      padding-bottom: 2px;
      background-color: #FF6230;
    }

    /* Source code view (function table): standard link - visited format */
    td.lineNoCov > a:visited,
    td.lineCov > a:visited
    {
      color: black;
      text-decoration: underline;
    }

    /* Source code view: format for lines which were executed only in a
       previous version */
    span.lineDiffCov
    {
      background-color: #B5F7AF;
    }

    /* Source code view: format for branches which were executed
     * and taken */
    span.branchCov
    {
      background-color: #00AA00;
    }

    /* Source code view: format for branches which were executed
     * but not taken */
    span.branchNoCov
    {
      background-color: #EFEF00;
    }

    /* Source code view: format for branches which were not executed */
    span.branchNoExec
    {
      background-color: #FF0000;
    }

    /* Source code view: format for the source code heading line */
    pre.sourceHeading
    {
      white-space: pre;
      font-family: monospace;
      font-weight: bold;
      margin: 0px;
    }

    /* All views: header legend value for low rate */
    td.headerValueLegL
    {
      font-family: sans-serif;
      text-align: center;
      white-space: nowrap;
      padding-left: 4px;
      padding-right: 2px;
      background-color: #FF0000;
      font-size: 80%;
    }

    /* All views: header legend value for med rate */
    td.headerValueLegM
    {
      font-family: sans-serif;
      text-align: center;
      white-space: nowrap;
      padding-left: 2px;
      padding-right: 2px;
      background-color: #FFEA20;
      font-size: 80%;
    }

    /* All views: header legend value for hi rate */
    td.headerValueLegH
    {
      font-family: sans-serif;
      text-align: center;
      white-space: nowrap;
      padding-left: 2px;
      padding-right: 4px;
      background-color: #A7FC9D;
      font-size: 80%;
    }

    /* All views except source code view: legend format for low coverage */
    span.coverLegendCovLo
    {
      padding-left: 10px;
      padding-right: 10px;
      padding-top: 2px;
      background-color: #FF0000;
    }

    /* All views except source code view: legend format for med coverage */
    span.coverLegendCovMed
    {
      padding-left: 10px;
      padding-right: 10px;
      padding-top: 2px;
      background-color: #FFEA20;
    }

    /* All views except source code view: legend format for hi coverage */
    span.coverLegendCovHi
    {
      padding-left: 10px;
      padding-right: 10px;
      padding-top: 2px;
      background-color: #A7FC9D;
    }
END_OF_CSS
    ;

    # *************************************************************


    # Remove leading tab from all lines
    $css_data =~ s/^\t//gm;

    print(CSS_HANDLE $css_data);

    close(CSS_HANDLE);
}


#
# get_bar_graph_code(base_dir, cover_found, cover_hit)
#
# Return a string containing HTML code which implements a bar graph display
# for a coverage rate of cover_hit * 100 / cover_found.
#

sub get_bar_graph_code($$$)
{
    my ($base_dir, $found, $hit) = @_;
    my $rate;
    my $alt;
    my $width;
    my $remainder;
    my $png_name;
    my $graph_code;

    # Check number of instrumented lines
    if ($_[1] == 0) { return ""; }

    $alt        = rate($hit, $found, "%");
    $width        = rate($hit, $found, undef, 0);
    $remainder    = 100 - $width;

    # Decide which .png file to use
    $png_name = $rate_png[classify_rate($found, $hit, $med_limit,
                        $hi_limit)];

    if ($width == 0)
    {
        # Zero coverage
        $graph_code = (<<END_OF_HTML)
            <table border=0 cellspacing=0 cellpadding=1><tr><td class="coverBarOutline"><img src="$_[0]snow.png" width=100 height=10 alt="$alt"></td></tr></table>
END_OF_HTML
        ;
    }
    elsif ($width == 100)
    {
        # Full coverage
        $graph_code = (<<END_OF_HTML)
        <table border=0 cellspacing=0 cellpadding=1><tr><td class="coverBarOutline"><img src="$_[0]$png_name" width=100 height=10 alt="$alt"></td></tr></table>
END_OF_HTML
        ;
    }
    else
    {
        # Positive coverage
        $graph_code = (<<END_OF_HTML)
        <table border=0 cellspacing=0 cellpadding=1><tr><td class="coverBarOutline"><img src="$_[0]$png_name" width=$width height=10 alt="$alt"><img src="$_[0]snow.png" width=$remainder height=10 alt="$alt"></td></tr></table>
END_OF_HTML
        ;
    }

    # Remove leading tabs from all lines
    $graph_code =~ s/^\t+//gm;
    chomp($graph_code);

    return($graph_code);
}

#
# sub classify_rate(found, hit, med_limit, high_limit)
#
# Return 0 for low rate, 1 for medium rate and 2 for hi rate.
#

sub classify_rate($$$$)
{
    my ($found, $hit, $med, $hi) = @_;
    my $rate;

    if ($found == 0) {
        return 2;
    }
    $rate = rate($hit, $found);
    if ($rate < $med) {
        return 0;
    } elsif ($rate < $hi) {
        return 1;
    }
    return 2;
}


#
# write_html(filehandle, html_code)
#
# Write out HTML_CODE to FILEHANDLE while removing a leading tabulator mark
# in each line of HTML_CODE.
#

sub write_html(*$)
{
    local *HTML_HANDLE = $_[0];
    my $html_code = $_[1];

    # Remove leading tab from all lines
    $html_code =~ s/^\t//gm;

    print(HTML_HANDLE $html_code)
        or die("ERROR: cannot write HTML data ($!)\n");
}


#
# write_html_prolog(filehandle, base_dir, pagetitle)
#
# Write an HTML prolog common to all HTML files to FILEHANDLE. PAGETITLE will
# be used as HTML page title. BASE_DIR contains a relative path which points
# to the base directory.
#

sub write_html_prolog(*$$)
{
    my $basedir = $_[1];
    my $pagetitle = $_[2];
    my $prolog;

    $prolog = $html_prolog;
    $prolog =~ s/\@pagetitle\@/$pagetitle/g;
    $prolog =~ s/\@basedir\@/$basedir/g;

    write_html($_[0], $prolog);
}


#
# write_header_prolog(filehandle, base_dir)
#
# Write beginning of page header HTML code.
#

sub write_header_prolog(*$)
{
    # *************************************************************

    write_html($_[0], <<END_OF_HTML)
      <table width="100%" border=0 cellspacing=0 cellpadding=0>
        <tr><td class="title">$title</td></tr>
        <tr><td class="ruler"><img src="$_[1]glass.png" width=3 height=3 alt=""></td></tr>

        <tr>
          <td width="100%">
            <table cellpadding=1 border=0 width="100%">
END_OF_HTML
    ;

    # *************************************************************
}


#
# write_header_line(handle, content)
#
# Write a header line with the specified table contents.
#

sub write_header_line(*@)
{
    my ($handle, @content) = @_;
    my $entry;

    write_html($handle, "          <tr>\n");
    foreach $entry (@content) {
        my ($width, $class, $text, $colspan) = @{$entry};

        if (defined($width)) {
            $width = " width=\"$width\"";
        } else {
            $width = "";
        }
        if (defined($class)) {
            $class = " class=\"$class\"";
        } else {
            $class = "";
        }
        if (defined($colspan)) {
            $colspan = " colspan=\"$colspan\"";
        } else {
            $colspan = "";
        }
        $text = "" if (!defined($text));
        write_html($handle,
               "            <td$width$class$colspan>$text</td>\n");
    }
    write_html($handle, "          </tr>\n");
}


#
# write_header_epilog(filehandle, base_dir)
#
# Write end of page header HTML code.
#

sub write_header_epilog(*$)
{
    # *************************************************************

    write_html($_[0], <<END_OF_HTML)
              <tr><td><img src="$_[1]glass.png" width=3 height=3 alt=""></td></tr>
            </table>
          </td>
        </tr>

        <tr><td class="ruler"><img src="$_[1]glass.png" width=3 height=3 alt=""></td></tr>
      </table>

END_OF_HTML
    ;

    # *************************************************************
}


#
# write_file_table_prolog(handle, file_heading, ([heading, num_cols], ...))
#
# Write heading for file table.
#

sub write_file_table_prolog(*$@)
{
    my ($handle, $file_heading, @columns) = @_;
    my $num_columns = 0;
    my $file_width;
    my $col;
    my $width;

    $width = 20 if (scalar(@columns) == 1);
    $width = 10 if (scalar(@columns) == 2);
    $width = 8 if (scalar(@columns) > 2);

    foreach $col (@columns) {
        my ($heading, $cols) = @{$col};

        $num_columns += $cols;
    }
    $file_width = 100 - $num_columns * $width;

    # Table definition
    write_html($handle, <<END_OF_HTML);
      <center>
      <table width="80%" cellpadding=1 cellspacing=1 border=0>

        <tr>
          <td width="$file_width%"><br></td>
END_OF_HTML
    # Empty first row
    foreach $col (@columns) {
        my ($heading, $cols) = @{$col};

        while ($cols-- > 0) {
            write_html($handle, <<END_OF_HTML);
          <td width="$width%"></td>
END_OF_HTML
        }
    }
    # Next row
    write_html($handle, <<END_OF_HTML);
        </tr>

        <tr>
          <td class="tableHead">$file_heading</td>
END_OF_HTML
    # Heading row
    foreach $col (@columns) {
        my ($heading, $cols) = @{$col};
        my $colspan = "";

        $colspan = " colspan=$cols" if ($cols > 1);
        write_html($handle, <<END_OF_HTML);
          <td class="tableHead"$colspan>$heading</td>
END_OF_HTML
    }
    write_html($handle, <<END_OF_HTML);
        </tr>
END_OF_HTML
}


# write_file_table_entry(handle, base_dir, filename, page_link,
#             ([ found, hit, med_limit, hi_limit, graph ], ..)
#
# Write an entry of the file table.
#

sub write_file_table_entry(*$$$@)
{
    my ($handle, $base_dir, $filename, $page_link, @entries) = @_;
    my $file_code;
    my $entry;
    my $esc_filename = escape_html($filename);

    # Add link to source if provided
    if (defined($page_link) && $page_link ne "") {
        $file_code = "<a href=\"$page_link\">$esc_filename</a>";
    } else {
        $file_code = $esc_filename;
    }

    # First column: filename
    write_html($handle, <<END_OF_HTML);
        <tr>
          <td class="coverFile">$file_code</td>
END_OF_HTML
    # Columns as defined
    foreach $entry (@entries) {
        my ($found, $hit, $med, $hi, $graph) = @{$entry};
        my $bar_graph;
        my $class;
        my $rate;

        # Generate bar graph if requested
        if ($graph) {
            $bar_graph = get_bar_graph_code($base_dir, $found,
                            $hit);
            write_html($handle, <<END_OF_HTML);
          <td class="coverBar" align="center">
            $bar_graph
          </td>
END_OF_HTML
        }
        # Get rate color and text
        if ($found == 0) {
            $rate = "-";
            $class = "Hi";
        } else {
            $rate = rate($hit, $found, "&nbsp;%");
            $class = $rate_name[classify_rate($found, $hit,
                        $med, $hi)];
        }
        write_html($handle, <<END_OF_HTML);
          <td class="coverPer$class">$rate</td>
          <td class="coverNum$class">$hit / $found</td>
END_OF_HTML
    }
    # End of row
        write_html($handle, <<END_OF_HTML);
        </tr>
END_OF_HTML
}


#
# write_file_table_detail_entry(filehandle, test_name, ([found, hit], ...))
#
# Write entry for detail section in file table.
#

sub write_file_table_detail_entry(*$@)
{
    my ($handle, $test, @entries) = @_;
    my $entry;

    if ($test eq "") {
        $test = "<span style=\"font-style:italic\">&lt;unnamed&gt;</span>";
    } elsif ($test =~ /^(.*),diff$/) {
        $test = $1." (converted)";
    }
    # Testname
    write_html($handle, <<END_OF_HTML);
        <tr>
          <td class="testName" colspan=2>$test</td>
END_OF_HTML
    # Test data
    foreach $entry (@entries) {
        my ($found, $hit) = @{$entry};
        my $rate = rate($hit, $found, "&nbsp;%");

        write_html($handle, <<END_OF_HTML);
          <td class="testPer">$rate</td>
          <td class="testNum">$hit&nbsp;/&nbsp;$found</td>
END_OF_HTML
    }

        write_html($handle, <<END_OF_HTML);
        </tr>

END_OF_HTML

    # *************************************************************
}


#
# write_file_table_epilog(filehandle)
#
# Write end of file table HTML code.
#

sub write_file_table_epilog(*)
{
    # *************************************************************

    write_html($_[0], <<END_OF_HTML)
      </table>
      </center>
      <br>

END_OF_HTML
    ;

    # *************************************************************
}


#
# write_test_table_prolog(filehandle, table_heading)
#
# Write heading for test case description table.
#

sub write_test_table_prolog(*$)
{
    # *************************************************************

    write_html($_[0], <<END_OF_HTML)
      <center>
      <table width="80%" cellpadding=2 cellspacing=1 border=0>

        <tr>
          <td><br></td>
        </tr>

        <tr>
          <td class="tableHead">$_[1]</td>
        </tr>

        <tr>
          <td class="testDescription">
            <dl>
END_OF_HTML
    ;

    # *************************************************************
}


#
# write_test_table_entry(filehandle, test_name, test_description)
#
# Write entry for the test table.
#

sub write_test_table_entry(*$$)
{
    # *************************************************************

    write_html($_[0], <<END_OF_HTML)
          <dt>$_[1]<a name="$_[1]">&nbsp;</a></dt>
          <dd>$_[2]<br><br></dd>
END_OF_HTML
    ;

    # *************************************************************
}


#
# write_test_table_epilog(filehandle)
#
# Write end of test description table HTML code.
#

sub write_test_table_epilog(*)
{
    # *************************************************************

    write_html($_[0], <<END_OF_HTML)
            </dl>
          </td>
        </tr>
      </table>
      </center>
      <br>

END_OF_HTML
    ;

    # *************************************************************
}


sub fmt_centered($$)
{
    my ($width, $text) = @_;
    my $w0 = length($text);
    my $w1 = int(($width - $w0) / 2);
    my $w2 = $width - $w0 - $w1;

    return (" "x$w1).$text.(" "x$w2);
}


#
# write_source_prolog(filehandle)
#
# Write start of source code table.
#

sub write_source_prolog(*)
{
    my $lineno_heading = "         ";
    my $branch_heading = "";
    my $line_heading = fmt_centered($line_field_width, "Line data");
    my $source_heading = " Source code";

    if ($br_coverage) {
        $branch_heading = fmt_centered($br_field_width, "Branch data").
                  " ";
    }
    # *************************************************************

    write_html($_[0], <<END_OF_HTML)
      <table cellpadding=0 cellspacing=0 border=0>
        <tr>
          <td><br></td>
        </tr>
        <tr>
          <td>
<pre class="sourceHeading">${lineno_heading}${branch_heading}${line_heading} ${source_heading}</pre>
<pre class="source">
END_OF_HTML
    ;

    # *************************************************************
}


#
# get_branch_blocks(brdata)
#
# Group branches that belong to the same basic block.
#
# Returns: [block1, block2, ...]
# block:   [branch1, branch2, ...]
# branch:  [block_num, branch_num, taken_count, text_length, open, close]
#

sub get_branch_blocks($)
{
    my ($brdata) = @_;
    my $last_block_num;
    my $block = [];
    my @blocks;
    my $i;
    my $num = br_ivec_len($brdata);

    # Group branches
    for ($i = 0; $i < $num; $i++) {
        my ($block_num, $branch, $taken) = br_ivec_get($brdata, $i);
        my $br;

        if (defined($last_block_num) && $block_num != $last_block_num) {
            push(@blocks, $block);
            $block = [];
        }
        $br = [$block_num, $branch, $taken, 3, 0, 0];
        push(@{$block}, $br);
        $last_block_num = $block_num;
    }
    push(@blocks, $block) if (scalar(@{$block}) > 0);

    # Add braces to first and last branch in group
    foreach $block (@blocks) {
        $block->[0]->[$BR_OPEN] = 1;
        $block->[0]->[$BR_LEN]++;
        $block->[scalar(@{$block}) - 1]->[$BR_CLOSE] = 1;
        $block->[scalar(@{$block}) - 1]->[$BR_LEN]++;
    }

    return @blocks;
}

#
# get_block_len(block)
#
# Calculate total text length of all branches in a block of branches.
#

sub get_block_len($)
{
    my ($block) = @_;
    my $len = 0;
    my $branch;

    foreach $branch (@{$block}) {
        $len += $branch->[$BR_LEN];
    }

    return $len;
}


#
# get_branch_html(brdata)
#
# Return a list of HTML lines which represent the specified branch coverage
# data in source code view.
#

sub get_branch_html($)
{
    my ($brdata) = @_;
    my @blocks = get_branch_blocks($brdata);
    my $block;
    my $branch;
    my $line_len = 0;
    my $line = [];    # [branch2|" ", branch|" ", ...]
    my @lines;    # [line1, line2, ...]
    my @result;

    # Distribute blocks to lines
    foreach $block (@blocks) {
        my $block_len = get_block_len($block);

        # Does this block fit into the current line?
        if ($line_len + $block_len <= $br_field_width) {
            # Add it
            $line_len += $block_len;
            push(@{$line}, @{$block});
            next;
        } elsif ($block_len <= $br_field_width) {
            # It would fit if the line was empty - add it to new
            # line
            push(@lines, $line);
            $line_len = $block_len;
            $line = [ @{$block} ];
            next;
        }
        # Split the block into several lines
        foreach $branch (@{$block}) {
            if ($line_len + $branch->[$BR_LEN] >= $br_field_width) {
                # Start a new line
                if (($line_len + 1 <= $br_field_width) &&
                    scalar(@{$line}) > 0 &&
                    !$line->[scalar(@$line) - 1]->[$BR_CLOSE]) {
                    # Try to align branch symbols to be in
                    # one # row
                    push(@{$line}, " ");
                }
                push(@lines, $line);
                $line_len = 0;
                $line = [];
            }
            push(@{$line}, $branch);
            $line_len += $branch->[$BR_LEN];
        }
    }
    push(@lines, $line);

    # Convert to HTML
    foreach $line (@lines) {
        my $current = "";
        my $current_len = 0;

        foreach $branch (@$line) {
            # Skip alignment space
            if ($branch eq " ") {
                $current .= " ";
                $current_len++;
                next;
            }

            my ($block_num, $br_num, $taken, $len, $open, $close) =
               @{$branch};
            my $class;
            my $title;
            my $text;

            if ($taken eq '-') {
                $class    = "branchNoExec";
                $text    = " # ";
                $title    = "Branch $br_num was not executed";
            } elsif ($taken == 0) {
                $class    = "branchNoCov";
                $text    = " - ";
                $title    = "Branch $br_num was not taken";
            } else {
                $class    = "branchCov";
                $text    = " + ";
                $title    = "Branch $br_num was taken $taken ".
                      "time";
                $title .= "s" if ($taken > 1);
            }
            $current .= "[" if ($open);
            $current .= "<span class=\"$class\" title=\"$title\">";
            $current .= $text."</span>";
            $current .= "]" if ($close);
            $current_len += $len;
        }

        # Right-align result text
        if ($current_len < $br_field_width) {
            $current = (" "x($br_field_width - $current_len)).
                   $current;
        }
        push(@result, $current);
    }

    return @result;
}


#
# format_count(count, width)
#
# Return a right-aligned representation of count that fits in width characters.
#

sub format_count($$)
{
    my ($count, $width) = @_;
    my $result;
    my $exp;

    $result = sprintf("%*.0f", $width, $count);
    while (length($result) > $width) {
        last if ($count < 10);
        $exp++;
        $count = int($count/10);
        $result = sprintf("%*s", $width, ">$count*10^$exp");
    }
    return $result;
}

#
# write_source_line(filehandle, line_num, source, hit_count, converted,
#                   brdata, add_anchor)
#
# Write formatted source code line. Return a line in a format as needed
# by gen_png()
#

sub write_source_line(*$$$$$$)
{
    my ($handle, $line, $source, $count, $converted, $brdata,
        $add_anchor) = @_;
    my $source_format;
    my $count_format;
    my $result;
    my $anchor_start = "";
    my $anchor_end = "";
    my $count_field_width = $line_field_width - 1;
    my @br_html;
    my $html;

    # Get branch HTML data for this line
    @br_html = get_branch_html($brdata) if ($br_coverage);

    if (!defined($count)) {
        $result        = "";
        $source_format    = "";
        $count_format    = " "x$count_field_width;
    }
    elsif ($count == 0) {
        $result        = $count;
        $source_format    = '<span class="lineNoCov">';
        $count_format    = format_count($count, $count_field_width);
    }
    elsif ($converted && defined($highlight)) {
        $result        = "*".$count;
        $source_format    = '<span class="lineDiffCov">';
        $count_format    = format_count($count, $count_field_width);
    }
    else {
        $result        = $count;
        $source_format    = '<span class="lineCov">';
        $count_format    = format_count($count, $count_field_width);
    }
    $result .= ":".$source;

    # Write out a line number navigation anchor every $nav_resolution
    # lines if necessary
    if ($add_anchor)
    {
        $anchor_start    = "<a name=\"$_[1]\">";
        $anchor_end    = "</a>";
    }


    # *************************************************************

    $html = $anchor_start;
    $html .= "<span class=\"lineNum\">".sprintf("%8d", $line)." </span>";
    $html .= shift(@br_html).":" if ($br_coverage);
    $html .= "$source_format$count_format : ";
    $html .= escape_html($source);
    $html .= "</span>" if ($source_format);
    $html .= $anchor_end."\n";

    write_html($handle, $html);

    if ($br_coverage) {
        # Add lines for overlong branch information
        foreach (@br_html) {
            write_html($handle, "<span class=\"lineNum\">".
                   "         </span>$_\n");
        }
    }
    # *************************************************************

    return($result);
}


#
# write_source_epilog(filehandle)
#
# Write end of source code table.
#

sub write_source_epilog(*)
{
    # *************************************************************

    write_html($_[0], <<END_OF_HTML)
    </pre>
          </td>
        </tr>
      </table>
      <br>

END_OF_HTML
    ;

    # *************************************************************
}


#
# write_html_epilog(filehandle, base_dir[, break_frames])
#
# Write HTML page footer to FILEHANDLE. BREAK_FRAMES should be set when
# this page is embedded in a frameset, clicking the URL link will then
# break this frameset.
#

sub write_html_epilog(*$;$)
{
    my $basedir = $_[1];
    my $break_code = "";
    my $epilog;

    if (defined($_[2]))
    {
        $break_code = " target=\"_parent\"";
    }

    # *************************************************************

    write_html($_[0], <<END_OF_HTML)
      <table width="100%" border=0 cellspacing=0 cellpadding=0>
        <tr><td class="ruler"><img src="$_[1]glass.png" width=3 height=3 alt=""></td></tr>
        <tr><td class="versionInfo">Generated by: <a href="$lcov_url"$break_code>$lcov_version</a></td></tr>
      </table>
      <br>
END_OF_HTML
    ;

    $epilog = $html_epilog;
    $epilog =~ s/\@basedir\@/$basedir/g;

    write_html($_[0], $epilog);
}


#
# write_frameset(filehandle, basedir, basename, pagetitle)
#
#

sub write_frameset(*$$$)
{
    my $frame_width = $overview_width + 40;

    # *************************************************************

    write_html($_[0], <<END_OF_HTML)
    <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN">

    <html lang="en">

    <head>
      <meta http-equiv="Content-Type" content="text/html; charset=$charset">
      <title>$_[3]</title>
      <link rel="stylesheet" type="text/css" href="$_[1]gcov.css">
    </head>

    <frameset cols="$frame_width,*">
      <frame src="$_[2].gcov.overview.$html_ext" name="overview">
      <frame src="$_[2].gcov.$html_ext" name="source">
      <noframes>
        <center>Frames not supported by your browser!<br></center>
      </noframes>
    </frameset>

    </html>
END_OF_HTML
    ;

    # *************************************************************
}


#
# sub write_overview_line(filehandle, basename, line, link)
#
#

sub write_overview_line(*$$$)
{
    my $y1 = $_[2] - 1;
    my $y2 = $y1 + $nav_resolution - 1;
    my $x2 = $overview_width - 1;

    # *************************************************************

    write_html($_[0], <<END_OF_HTML)
        <area shape="rect" coords="0,$y1,$x2,$y2" href="$_[1].gcov.$html_ext#$_[3]" target="source" alt="overview">
END_OF_HTML
    ;

    # *************************************************************
}


#
# write_overview(filehandle, basedir, basename, pagetitle, lines)
#
#

sub write_overview(*$$$$)
{
    my $index;
    my $max_line = $_[4] - 1;
    my $offset;

    # *************************************************************

    write_html($_[0], <<END_OF_HTML)
    <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">

    <html lang="en">

    <head>
      <title>$_[3]</title>
      <meta http-equiv="Content-Type" content="text/html; charset=$charset">
      <link rel="stylesheet" type="text/css" href="$_[1]gcov.css">
    </head>

    <body>
      <map name="overview">
END_OF_HTML
    ;

    # *************************************************************

    # Make $offset the next higher multiple of $nav_resolution
    $offset = ($nav_offset + $nav_resolution - 1) / $nav_resolution;
    $offset = sprintf("%d", $offset ) * $nav_resolution;

    # Create image map for overview image
    for ($index = 1; $index <= $_[4]; $index += $nav_resolution)
    {
        # Enforce nav_offset
        if ($index < $offset + 1)
        {
            write_overview_line($_[0], $_[2], $index, 1);
        }
        else
        {
            write_overview_line($_[0], $_[2], $index, $index - $offset);
        }
    }

    # *************************************************************

    write_html($_[0], <<END_OF_HTML)
      </map>

      <center>
      <a href="$_[2].gcov.$html_ext#top" target="source">Top</a><br><br>
      <img src="$_[2].gcov.png" width=$overview_width height=$max_line alt="Overview" border=0 usemap="#overview">
      </center>
    </body>
    </html>
END_OF_HTML
    ;

    # *************************************************************
}


sub max($$)
{
    my ($a, $b) = @_;

    return $a if ($a > $b);
    return $b;
}


#
# write_header(filehandle, type, trunc_file_name, rel_file_name, lines_found,
# lines_hit, funcs_found, funcs_hit, sort_type)
#
# Write a complete standard page header. TYPE may be (0, 1, 2, 3, 4)
# corresponding to (directory view header, file view header, source view
# header, test case description header, function view header)
#

sub write_header(*$$$$$$$$$$)
{
    local *HTML_HANDLE = $_[0];
    my $type = $_[1];
    my $trunc_name = $_[2];
    my $rel_filename = $_[3];
    my $lines_found = $_[4];
    my $lines_hit = $_[5];
    my $fn_found = $_[6];
    my $fn_hit = $_[7];
    my $br_found = $_[8];
    my $br_hit = $_[9];
    my $sort_type = $_[10];
    my $base_dir;
    my $view;
    my $test;
    my $base_name;
    my $style;
    my $rate;
    my @row_left;
    my @row_right;
    my $num_rows;
    my $i;
    my $esc_trunc_name = escape_html($trunc_name);

    $base_name = basename($rel_filename);

    # Prepare text for "current view" field
    if ($type == $HDR_DIR)
    {
        # Main overview
        $base_dir = "";
        $view = $overview_title;
    }
    elsif ($type == $HDR_FILE)
    {
        # Directory overview
        $base_dir = get_relative_base_path($rel_filename);
        $view = "<a href=\"$base_dir"."index.$html_ext\">".
            "$overview_title</a> - $esc_trunc_name";
    }
    elsif ($type == $HDR_SOURCE || $type == $HDR_FUNC)
    {
        # File view
        my $dir_name = dirname($rel_filename);
        my $esc_base_name = escape_html($base_name);
        my $esc_dir_name = escape_html($dir_name);

        $base_dir = get_relative_base_path($dir_name);
        if ($frames)
        {
            # Need to break frameset when clicking any of these
            # links
            $view = "<a href=\"$base_dir"."index.$html_ext\" ".
                "target=\"_parent\">$overview_title</a> - ".
                "<a href=\"index.$html_ext\" target=\"_parent\">".
                "$esc_dir_name</a> - $esc_base_name";
        }
        else
        {
            $view = "<a href=\"$base_dir"."index.$html_ext\">".
                "$overview_title</a> - ".
                "<a href=\"index.$html_ext\">".
                "$esc_dir_name</a> - $esc_base_name";
        }

        # Add function suffix
        if ($func_coverage) {
            $view .= "<span style=\"font-size: 80%;\">";
            if ($type == $HDR_SOURCE) {
                if ($sort) {
                    $view .= " (source / <a href=\"$base_name.func-sort-c.$html_ext\">functions</a>)";
                } else {
                    $view .= " (source / <a href=\"$base_name.func.$html_ext\">functions</a>)";
                }
            } elsif ($type == $HDR_FUNC) {
                $view .= " (<a href=\"$base_name.gcov.$html_ext\">source</a> / functions)";
            }
            $view .= "</span>";
        }
    }
    elsif ($type == $HDR_TESTDESC)
    {
        # Test description header
        $base_dir = "";
        $view = "<a href=\"$base_dir"."index.$html_ext\">".
            "$overview_title</a> - test case descriptions";
    }

    # Prepare text for "test" field
    $test = escape_html($test_title);

    # Append link to test description page if available
    if (%test_description && ($type != $HDR_TESTDESC))
    {
        if ($frames && ($type == $HDR_SOURCE || $type == $HDR_FUNC))
        {
            # Need to break frameset when clicking this link
            $test .= " ( <span style=\"font-size:80%;\">".
                 "<a href=\"$base_dir".
                 "descriptions.$html_ext\" target=\"_parent\">".
                 "view descriptions</a></span> )";
        }
        else
        {
            $test .= " ( <span style=\"font-size:80%;\">".
                 "<a href=\"$base_dir".
                 "descriptions.$html_ext\">".
                 "view descriptions</a></span> )";
        }
    }

    # Write header
    write_header_prolog(*HTML_HANDLE, $base_dir);

    # Left row
    push(@row_left, [[ "10%", "headerItem", "Current view:" ],
             [ "35%", "headerValue", $view ]]);
    push(@row_left, [[undef, "headerItem", "Test:"],
             [undef, "headerValue", $test]]);
    push(@row_left, [[undef, "headerItem", "Date:"],
             [undef, "headerValue", $date]]);

    # Right row
    if ($legend && ($type == $HDR_SOURCE || $type == $HDR_FUNC)) {
        my $text = <<END_OF_HTML;
            Lines:
            <span class="coverLegendCov">hit</span>
            <span class="coverLegendNoCov">not hit</span>
END_OF_HTML
        if ($br_coverage) {
            $text .= <<END_OF_HTML;
            | Branches:
            <span class="coverLegendCov">+</span> taken
            <span class="coverLegendNoCov">-</span> not taken
            <span class="coverLegendNoCov">#</span> not executed
END_OF_HTML
        }
        push(@row_left, [[undef, "headerItem", "Legend:"],
                 [undef, "headerValueLeg", $text]]);
    } elsif ($legend && ($type != $HDR_TESTDESC)) {
        my $text = <<END_OF_HTML;
        Rating:
            <span class="coverLegendCovLo" title="Coverage rates below $med_limit % are classified as low">low: &lt; $med_limit %</span>
            <span class="coverLegendCovMed" title="Coverage rates between $med_limit % and $hi_limit % are classified as medium">medium: &gt;= $med_limit %</span>
            <span class="coverLegendCovHi" title="Coverage rates of $hi_limit % and more are classified as high">high: &gt;= $hi_limit %</span>
END_OF_HTML
        push(@row_left, [[undef, "headerItem", "Legend:"],
                 [undef, "headerValueLeg", $text]]);
    }
    if ($type == $HDR_TESTDESC) {
        push(@row_right, [[ "55%" ]]);
    } else {
        push(@row_right, [["15%", undef, undef ],
                  ["10%", "headerCovTableHead", "Hit" ],
                  ["10%", "headerCovTableHead", "Total" ],
                  ["15%", "headerCovTableHead", "Coverage"]]);
    }
    # Line coverage
    $style = $rate_name[classify_rate($lines_found, $lines_hit,
                      $med_limit, $hi_limit)];
    $rate = rate($lines_hit, $lines_found, " %");
    push(@row_right, [[undef, "headerItem", "Lines:"],
              [undef, "headerCovTableEntry", $lines_hit],
              [undef, "headerCovTableEntry", $lines_found],
              [undef, "headerCovTableEntry$style", $rate]])
            if ($type != $HDR_TESTDESC);
    # Function coverage
    if ($func_coverage) {
        $style = $rate_name[classify_rate($fn_found, $fn_hit,
                          $fn_med_limit, $fn_hi_limit)];
        $rate = rate($fn_hit, $fn_found, " %");
        push(@row_right, [[undef, "headerItem", "Functions:"],
                  [undef, "headerCovTableEntry", $fn_hit],
                  [undef, "headerCovTableEntry", $fn_found],
                  [undef, "headerCovTableEntry$style", $rate]])
            if ($type != $HDR_TESTDESC);
    }
    # Branch coverage
    if ($br_coverage) {
        $style = $rate_name[classify_rate($br_found, $br_hit,
                          $br_med_limit, $br_hi_limit)];
        $rate = rate($br_hit, $br_found, " %");
        push(@row_right, [[undef, "headerItem", "Branches:"],
                  [undef, "headerCovTableEntry", $br_hit],
                  [undef, "headerCovTableEntry", $br_found],
                  [undef, "headerCovTableEntry$style", $rate]])
            if ($type != $HDR_TESTDESC);
    }

    # Print rows
    $num_rows = max(scalar(@row_left), scalar(@row_right));
    for ($i = 0; $i < $num_rows; $i++) {
        my $left = $row_left[$i];
        my $right = $row_right[$i];

        if (!defined($left)) {
            $left = [[undef, undef, undef], [undef, undef, undef]];
        }
        if (!defined($right)) {
            $right = [];
        }
        write_header_line(*HTML_HANDLE, @{$left},
                  [ $i == 0 ? "5%" : undef, undef, undef],
                  @{$right});
    }

    # Fourth line
    write_header_epilog(*HTML_HANDLE, $base_dir);
}


#
# get_sorted_keys(hash_ref, sort_type)
#

sub get_sorted_keys($$)
{
    my ($hash, $type) = @_;

    if ($type == $SORT_FILE) {
        # Sort by name
        return sort(keys(%{$hash}));
    } elsif ($type == $SORT_LINE) {
        # Sort by line coverage
        return sort({$hash->{$a}[7] <=> $hash->{$b}[7]} keys(%{$hash}));
    } elsif ($type == $SORT_FUNC) {
        # Sort by function coverage;
        return sort({$hash->{$a}[8] <=> $hash->{$b}[8]}    keys(%{$hash}));
    } elsif ($type == $SORT_BRANCH) {
        # Sort by br coverage;
        return sort({$hash->{$a}[9] <=> $hash->{$b}[9]}    keys(%{$hash}));
    }
}

sub get_sort_code($$$)
{
    my ($link, $alt, $base) = @_;
    my $png;
    my $link_start;
    my $link_end;

    if (!defined($link)) {
        $png = "glass.png";
        $link_start = "";
        $link_end = "";
    } else {
        $png = "updown.png";
        $link_start = '<a href="'.$link.'">';
        $link_end = "</a>";
    }

    return ' <span class="tableHeadSort">'.$link_start.
           '<img src="'.$base.$png.'" width=10 height=14 '.
           'alt="'.$alt.'" title="'.$alt.'" border=0>'.$link_end.'</span>';
}

sub get_file_code($$$$)
{
    my ($type, $text, $sort_button, $base) = @_;
    my $result = $text;
    my $link;

    if ($sort_button) {
        if ($type == $HEAD_NO_DETAIL) {
            $link = "index.$html_ext";
        } else {
            $link = "index-detail.$html_ext";
        }
    }
    $result .= get_sort_code($link, "Sort by name", $base);

    return $result;
}

sub get_line_code($$$$$)
{
    my ($type, $sort_type, $text, $sort_button, $base) = @_;
    my $result = $text;
    my $sort_link;

    if ($type == $HEAD_NO_DETAIL) {
        # Just text
        if ($sort_button) {
            $sort_link = "index-sort-l.$html_ext";
        }
    } elsif ($type == $HEAD_DETAIL_HIDDEN) {
        # Text + link to detail view
        $result .= ' ( <a class="detail" href="index-detail'.
               $fileview_sortname[$sort_type].'.'.$html_ext.
               '">show details</a> )';
        if ($sort_button) {
            $sort_link = "index-sort-l.$html_ext";
        }
    } else {
        # Text + link to standard view
        $result .= ' ( <a class="detail" href="index'.
               $fileview_sortname[$sort_type].'.'.$html_ext.
               '">hide details</a> )';
        if ($sort_button) {
            $sort_link = "index-detail-sort-l.$html_ext";
        }
    }
    # Add sort button
    $result .= get_sort_code($sort_link, "Sort by line coverage", $base);

    return $result;
}

sub get_func_code($$$$)
{
    my ($type, $text, $sort_button, $base) = @_;
    my $result = $text;
    my $link;

    if ($sort_button) {
        if ($type == $HEAD_NO_DETAIL) {
            $link = "index-sort-f.$html_ext";
        } else {
            $link = "index-detail-sort-f.$html_ext";
        }
    }
    $result .= get_sort_code($link, "Sort by function coverage", $base);
    return $result;
}

sub get_br_code($$$$)
{
    my ($type, $text, $sort_button, $base) = @_;
    my $result = $text;
    my $link;

    if ($sort_button) {
        if ($type == $HEAD_NO_DETAIL) {
            $link = "index-sort-b.$html_ext";
        } else {
            $link = "index-detail-sort-b.$html_ext";
        }
    }
    $result .= get_sort_code($link, "Sort by branch coverage", $base);
    return $result;
}

#
# write_file_table(filehandle, base_dir, overview, testhash, testfnchash,
#                  testbrhash, fileview, sort_type)
#
# Write a complete file table. OVERVIEW is a reference to a hash containing
# the following mapping:
#
#   filename -> "lines_found,lines_hit,funcs_found,funcs_hit,page_link,
#         func_link"
#
# TESTHASH is a reference to the following hash:
#
#   filename -> \%testdata
#   %testdata: name of test affecting this file -> \%testcount
#   %testcount: line number -> execution count for a single test
#
# Heading of first column is "Filename" if FILEVIEW is true, "Directory name"
# otherwise.
#

sub write_file_table(*$$$$$$$)
{
    local *HTML_HANDLE = $_[0];
    my $base_dir = $_[1];
    my $overview = $_[2];
    my $testhash = $_[3];
    my $testfnchash = $_[4];
    my $testbrhash = $_[5];
    my $fileview = $_[6];
    my $sort_type = $_[7];
    my $filename;
    my $bar_graph;
    my $hit;
    my $found;
    my $fn_found;
    my $fn_hit;
    my $br_found;
    my $br_hit;
    my $page_link;
    my $testname;
    my $testdata;
    my $testfncdata;
    my $testbrdata;
    my %affecting_tests;
    my $line_code = "";
    my $func_code;
    my $br_code;
    my $file_code;
    my @head_columns;

    # Determine HTML code for column headings
    if (($base_dir ne "") && $show_details)
    {
        my $detailed = keys(%{$testhash});

        $file_code = get_file_code($detailed ? $HEAD_DETAIL_HIDDEN :
                    $HEAD_NO_DETAIL,
                    $fileview ? "Filename" : "Directory",
                    $sort && $sort_type != $SORT_FILE,
                    $base_dir);
        $line_code = get_line_code($detailed ? $HEAD_DETAIL_SHOWN :
                    $HEAD_DETAIL_HIDDEN,
                    $sort_type,
                    "Line Coverage",
                    $sort && $sort_type != $SORT_LINE,
                    $base_dir);
        $func_code = get_func_code($detailed ? $HEAD_DETAIL_HIDDEN :
                    $HEAD_NO_DETAIL,
                    "Functions",
                    $sort && $sort_type != $SORT_FUNC,
                    $base_dir);
        $br_code = get_br_code($detailed ? $HEAD_DETAIL_HIDDEN :
                    $HEAD_NO_DETAIL,
                    "Branches",
                    $sort && $sort_type != $SORT_BRANCH,
                    $base_dir);
    } else {
        $file_code = get_file_code($HEAD_NO_DETAIL,
                    $fileview ? "Filename" : "Directory",
                    $sort && $sort_type != $SORT_FILE,
                    $base_dir);
        $line_code = get_line_code($HEAD_NO_DETAIL, $sort_type, "Line Coverage",
                    $sort && $sort_type != $SORT_LINE,
                    $base_dir);
        $func_code = get_func_code($HEAD_NO_DETAIL, "Functions",
                    $sort && $sort_type != $SORT_FUNC,
                    $base_dir);
        $br_code = get_br_code($HEAD_NO_DETAIL, "Branches",
                    $sort && $sort_type != $SORT_BRANCH,
                    $base_dir);
    }
    push(@head_columns, [ $line_code, 3 ]);
    push(@head_columns, [ $func_code, 2]) if ($func_coverage);
    push(@head_columns, [ $br_code, 2]) if ($br_coverage);

    write_file_table_prolog(*HTML_HANDLE, $file_code, @head_columns);

    foreach $filename (get_sorted_keys($overview, $sort_type))
    {
        my @columns;
        ($found, $hit, $fn_found, $fn_hit, $br_found, $br_hit,
         $page_link) = @{$overview->{$filename}};

        # Line coverage
        push(@columns, [$found, $hit, $med_limit, $hi_limit, 1]);
        # Function coverage
        if ($func_coverage) {
            push(@columns, [$fn_found, $fn_hit, $fn_med_limit,
                    $fn_hi_limit, 0]);
        }
        # Branch coverage
        if ($br_coverage) {
            push(@columns, [$br_found, $br_hit, $br_med_limit,
                    $br_hi_limit, 0]);
        }
        write_file_table_entry(*HTML_HANDLE, $base_dir, $filename,
                       $page_link, @columns);

        $testdata = $testhash->{$filename};
        $testfncdata = $testfnchash->{$filename};
        $testbrdata = $testbrhash->{$filename};

        # Check whether we should write test specific coverage
        # as well
        if (!($show_details && $testdata)) { next; }

        # Filter out those tests that actually affect this file
        %affecting_tests = %{ get_affecting_tests($testdata,
                    $testfncdata, $testbrdata) };

        # Does any of the tests affect this file at all?
        if (!%affecting_tests) { next; }

        foreach $testname (keys(%affecting_tests))
        {
            my @results;
            ($found, $hit, $fn_found, $fn_hit, $br_found, $br_hit) =
                split(",", $affecting_tests{$testname});

            # Insert link to description of available
            if ($test_description{$testname})
            {
                $testname = "<a href=\"$base_dir".
                        "descriptions.$html_ext#$testname\">".
                        "$testname</a>";
            }

            push(@results, [$found, $hit]);
            push(@results, [$fn_found, $fn_hit]) if ($func_coverage);
            push(@results, [$br_found, $br_hit]) if ($br_coverage);
            write_file_table_detail_entry(*HTML_HANDLE, $testname,
                @results);
        }
    }

    write_file_table_epilog(*HTML_HANDLE);
}


#
# get_found_and_hit(hash)
#
# Return the count for entries (found) and entries with an execution count
# greater than zero (hit) in a hash (linenumber -> execution count) as
# a list (found, hit)
#

sub get_found_and_hit($)
{
    my %hash = %{$_[0]};
    my $found = 0;
    my $hit = 0;

    # Calculate sum
    $found = 0;
    $hit = 0;

    foreach (keys(%hash))
    {
        $found++;
        if ($hash{$_}>0) { $hit++; }
    }

    return ($found, $hit);
}


#
# get_func_found_and_hit(sumfnccount)
#
# Return (f_found, f_hit) for sumfnccount
#

sub get_func_found_and_hit($)
{
    my ($sumfnccount) = @_;
    my $function;
    my $fn_found;
    my $fn_hit;

    $fn_found = scalar(keys(%{$sumfnccount}));
    $fn_hit = 0;
    foreach $function (keys(%{$sumfnccount})) {
        if ($sumfnccount->{$function} > 0) {
            $fn_hit++;
        }
    }
    return ($fn_found, $fn_hit);
}


#
# br_taken_to_num(taken)
#
# Convert a branch taken value .info format to number format.
#

sub br_taken_to_num($)
{
    my ($taken) = @_;

    return 0 if ($taken eq '-');
    return $taken + 1;
}


#
# br_num_to_taken(taken)
#
# Convert a branch taken value in number format to .info format.
#

sub br_num_to_taken($)
{
    my ($taken) = @_;

    return '-' if ($taken == 0);
    return $taken - 1;
}


#
# br_taken_add(taken1, taken2)
#
# Return the result of taken1 + taken2 for 'branch taken' values.
#

sub br_taken_add($$)
{
    my ($t1, $t2) = @_;

    return $t1 if (!defined($t2));
    return $t2 if (!defined($t1));
    return $t1 if ($t2 eq '-');
    return $t2 if ($t1 eq '-');
    return $t1 + $t2;
}


#
# br_taken_sub(taken1, taken2)
#
# Return the result of taken1 - taken2 for 'branch taken' values. Return 0
# if the result would become negative.
#

sub br_taken_sub($$)
{
    my ($t1, $t2) = @_;

    return $t1 if (!defined($t2));
    return undef if (!defined($t1));
    return $t1 if ($t1 eq '-');
    return $t1 if ($t2 eq '-');
    return 0 if $t2 > $t1;
    return $t1 - $t2;
}


#
# br_ivec_len(vector)
#
# Return the number of entries in the branch coverage vector.
#

sub br_ivec_len($)
{
    my ($vec) = @_;

    return 0 if (!defined($vec));
    return (length($vec) * 8 / $BR_VEC_WIDTH) / $BR_VEC_ENTRIES;
}


#
# br_ivec_get(vector, number)
#
# Return an entry from the branch coverage vector.
#

sub br_ivec_get($$)
{
    my ($vec, $num) = @_;
    my $block;
    my $branch;
    my $taken;
    my $offset = $num * $BR_VEC_ENTRIES;

    # Retrieve data from vector
    $block    = vec($vec, $offset + $BR_BLOCK, $BR_VEC_WIDTH);
    $block = -1 if ($block == $BR_VEC_MAX);
    $branch = vec($vec, $offset + $BR_BRANCH, $BR_VEC_WIDTH);
    $taken    = vec($vec, $offset + $BR_TAKEN, $BR_VEC_WIDTH);

    # Decode taken value from an integer
    $taken = br_num_to_taken($taken);

    return ($block, $branch, $taken);
}


#
# br_ivec_push(vector, block, branch, taken)
#
# Add an entry to the branch coverage vector. If an entry with the same
# branch ID already exists, add the corresponding taken values.
#

sub br_ivec_push($$$$)
{
    my ($vec, $block, $branch, $taken) = @_;
    my $offset;
    my $num = br_ivec_len($vec);
    my $i;

    $vec = "" if (!defined($vec));
    $block = $BR_VEC_MAX if $block < 0;

    # Check if branch already exists in vector
    for ($i = 0; $i < $num; $i++) {
        my ($v_block, $v_branch, $v_taken) = br_ivec_get($vec, $i);
        $v_block = $BR_VEC_MAX if $v_block < 0;

        next if ($v_block != $block || $v_branch != $branch);

        # Add taken counts
        $taken = br_taken_add($taken, $v_taken);
        last;
    }

    $offset = $i * $BR_VEC_ENTRIES;
    $taken = br_taken_to_num($taken);

    # Add to vector
    vec($vec, $offset + $BR_BLOCK, $BR_VEC_WIDTH) = $block;
    vec($vec, $offset + $BR_BRANCH, $BR_VEC_WIDTH) = $branch;
    vec($vec, $offset + $BR_TAKEN, $BR_VEC_WIDTH) = $taken;

    return $vec;
}


#
# get_br_found_and_hit(sumbrcount)
#
# Return (br_found, br_hit) for sumbrcount
#

sub get_br_found_and_hit($)
{
    my ($sumbrcount) = @_;
    my $line;
    my $br_found = 0;
    my $br_hit = 0;

    foreach $line (keys(%{$sumbrcount})) {
        my $brdata = $sumbrcount->{$line};
        my $i;
        my $num = br_ivec_len($brdata);

        for ($i = 0; $i < $num; $i++) {
            my $taken;

            (undef, undef, $taken) = br_ivec_get($brdata, $i);

            $br_found++;
            $br_hit++ if ($taken ne "-" && $taken > 0);
        }
    }

    return ($br_found, $br_hit);
}


#
# get_affecting_tests(testdata, testfncdata, testbrdata)
#
# HASHREF contains a mapping filename -> (linenumber -> exec count). Return
# a hash containing mapping filename -> "lines found, lines hit" for each
# filename which has a nonzero hit count.
#

sub get_affecting_tests($$$)
{
    my ($testdata, $testfncdata, $testbrdata) = @_;
    my $testname;
    my $testcount;
    my $testfnccount;
    my $testbrcount;
    my %result;
    my $found;
    my $hit;
    my $fn_found;
    my $fn_hit;
    my $br_found;
    my $br_hit;

    foreach $testname (keys(%{$testdata}))
    {
        # Get (line number -> count) hash for this test case
        $testcount = $testdata->{$testname};
        $testfnccount = $testfncdata->{$testname};
        $testbrcount = $testbrdata->{$testname};

        # Calculate sum
        ($found, $hit) = get_found_and_hit($testcount);
        ($fn_found, $fn_hit) = get_func_found_and_hit($testfnccount);
        ($br_found, $br_hit) = get_br_found_and_hit($testbrcount);

        if ($hit>0)
        {
            $result{$testname} = "$found,$hit,$fn_found,$fn_hit,".
                         "$br_found,$br_hit";
        }
    }

    return(\%result);
}


sub get_hash_reverse($)
{
    my ($hash) = @_;
    my %result;

    foreach (keys(%{$hash})) {
        $result{$hash->{$_}} = $_;
    }

    return \%result;
}

#
# write_source(filehandle, source_filename, count_data, checksum_data,
#              converted_data, func_data, sumbrcount)
#
# Write an HTML view of a source code file. Returns a list containing
# data as needed by gen_png().
#
# Die on error.
#

sub write_source($$$$$$$)
{
    local *HTML_HANDLE = $_[0];
    local *SOURCE_HANDLE;
    my $source_filename = $_[1];
    my %count_data;
    my $line_number;
    my @result;
    my $checkdata = $_[3];
    my $converted = $_[4];
    my $funcdata  = $_[5];
    my $sumbrcount = $_[6];
    my $datafunc = get_hash_reverse($funcdata);
    my $add_anchor;
    my @file;

    if ($_[2])
    {
        %count_data = %{$_[2]};
    }

    if (!open(SOURCE_HANDLE, "<", $source_filename)) {
        my @lines;
        my $last_line = 0;

        if (!$ignore[$ERROR_SOURCE]) {
            die("ERROR: cannot read $source_filename\n");
        }

        # Continue without source file
        warn("WARNING: cannot read $source_filename!\n");

        @lines = sort( { $a <=> $b }  keys(%count_data));
        if (@lines) {
            $last_line = $lines[scalar(@lines) - 1];
        }
        return ( ":" ) if ($last_line < 1);

        # Simulate gcov behavior
        for ($line_number = 1; $line_number <= $last_line;
             $line_number++) {
            push(@file, "/* EOF */");
        }
    } else {
        @file = <SOURCE_HANDLE>;
    }

    write_source_prolog(*HTML_HANDLE);
    $line_number = 0;
    foreach (@file) {
        $line_number++;
        chomp($_);

        # Also remove CR from line-end
        s/\015$//;

        # Source code matches coverage data?
        if (defined($checkdata->{$line_number}) &&
            ($checkdata->{$line_number} ne md5_base64($_)))
        {
            die("ERROR: checksum mismatch  at $source_filename:".
                "$line_number\n");
        }

        $add_anchor = 0;
        if ($frames) {
            if (($line_number - 1) % $nav_resolution == 0) {
                $add_anchor = 1;
            }
        }
        if ($func_coverage) {
            if ($line_number == 1) {
                $add_anchor = 1;
            } elsif (defined($datafunc->{$line_number +
                             $func_offset})) {
                $add_anchor = 1;
            }
        }
        push (@result,
              write_source_line(HTML_HANDLE, $line_number,
                    $_, $count_data{$line_number},
                    $converted->{$line_number},
                    $sumbrcount->{$line_number}, $add_anchor));
    }

    close(SOURCE_HANDLE);
    write_source_epilog(*HTML_HANDLE);
    return(@result);
}


sub funcview_get_func_code($$$)
{
    my ($name, $base, $type) = @_;
    my $result;
    my $link;

    if ($sort && $type == 1) {
        $link = "$name.func.$html_ext";
    }
    $result = "Function Name";
    $result .= get_sort_code($link, "Sort by function name", $base);

    return $result;
}

sub funcview_get_count_code($$$)
{
    my ($name, $base, $type) = @_;
    my $result;
    my $link;

    if ($sort && $type == 0) {
        $link = "$name.func-sort-c.$html_ext";
    }
    $result = "Hit count";
    $result .= get_sort_code($link, "Sort by hit count", $base);

    return $result;
}

#
# funcview_get_sorted(funcdata, sumfncdata, sort_type)
#
# Depending on the value of sort_type, return a list of functions sorted
# by name (type 0) or by the associated call count (type 1).
#

sub funcview_get_sorted($$$)
{
    my ($funcdata, $sumfncdata, $type) = @_;

    if ($type == 0) {
        return sort(keys(%{$funcdata}));
    }
    return sort({
        $sumfncdata->{$b} == $sumfncdata->{$a} ?
            $a cmp $b : $sumfncdata->{$a} <=> $sumfncdata->{$b}
        } keys(%{$sumfncdata}));
}

#
# write_function_table(filehandle, source_file, sumcount, funcdata,
#               sumfnccount, testfncdata, sumbrcount, testbrdata,
#               base_name, base_dir, sort_type)
#
# Write an HTML table listing all functions in a source file, including
# also function call counts and line coverages inside of each function.
#
# Die on error.
#

sub write_function_table(*$$$$$$$$$$)
{
    local *HTML_HANDLE = $_[0];
    my $source = $_[1];
    my $sumcount = $_[2];
    my $funcdata = $_[3];
    my $sumfncdata = $_[4];
    my $testfncdata = $_[5];
    my $sumbrcount = $_[6];
    my $testbrdata = $_[7];
    my $name = $_[8];
    my $base = $_[9];
    my $type = $_[10];
    my $func;
    my $func_code;
    my $count_code;

    # Get HTML code for headings
    $func_code = funcview_get_func_code($name, $base, $type);
    $count_code = funcview_get_count_code($name, $base, $type);
    write_html(*HTML_HANDLE, <<END_OF_HTML)
      <center>
      <table width="60%" cellpadding=1 cellspacing=1 border=0>
        <tr><td><br></td></tr>
        <tr>
          <td width="80%" class="tableHead">$func_code</td>
          <td width="20%" class="tableHead">$count_code</td>
        </tr>
END_OF_HTML
    ;

    # Get a sorted table
    foreach $func (funcview_get_sorted($funcdata, $sumfncdata, $type)) {
        if (!defined($funcdata->{$func}))
        {
            next;
        }

        my $startline = $funcdata->{$func} - $func_offset;
        my $name = $func;
        my $count = $sumfncdata->{$name};
        my $countstyle;

        # Escape special characters
        $name = escape_html($name);
        if ($startline < 1) {
            $startline = 1;
        }
        if ($count == 0) {
            $countstyle = "coverFnLo";
        } else {
            $countstyle = "coverFnHi";
        }

        write_html(*HTML_HANDLE, <<END_OF_HTML)
        <tr>
              <td class="coverFn"><a href="$source#$startline">$name</a></td>
              <td class="$countstyle">$count</td>
            </tr>
END_OF_HTML
                ;
    }
    write_html(*HTML_HANDLE, <<END_OF_HTML)
      </table>
      <br>
      </center>
END_OF_HTML
    ;
}


#
# info(printf_parameter)
#
# Use printf to write PRINTF_PARAMETER to stdout only when the $quiet flag
# is not set.
#

sub info(@)
{
    if (!$quiet)
    {
        # Print info string
        printf(@_);
    }
}


#
# subtract_counts(data_ref, base_ref)
#

sub subtract_counts($$)
{
    my %data = %{$_[0]};
    my %base = %{$_[1]};
    my $line;
    my $data_count;
    my $base_count;
    my $hit = 0;
    my $found = 0;

    foreach $line (keys(%data))
    {
        $found++;
        $data_count = $data{$line};
        $base_count = $base{$line};

        if (defined($base_count))
        {
            $data_count -= $base_count;

            # Make sure we don't get negative numbers
            if ($data_count<0) { $data_count = 0; }
        }

        $data{$line} = $data_count;
        if ($data_count > 0) { $hit++; }
    }

    return (\%data, $found, $hit);
}


#
# subtract_fnccounts(data, base)
#
# Subtract function call counts found in base from those in data.
# Return (data, f_found, f_hit).
#

sub subtract_fnccounts($$)
{
    my %data;
    my %base;
    my $func;
    my $data_count;
    my $base_count;
    my $fn_hit = 0;
    my $fn_found = 0;

    %data = %{$_[0]} if (defined($_[0]));
    %base = %{$_[1]} if (defined($_[1]));
    foreach $func (keys(%data)) {
        $fn_found++;
        $data_count = $data{$func};
        $base_count = $base{$func};

        if (defined($base_count)) {
            $data_count -= $base_count;

            # Make sure we don't get negative numbers
            if ($data_count < 0) {
                $data_count = 0;
            }
        }

        $data{$func} = $data_count;
        if ($data_count > 0) {
            $fn_hit++;
        }
    }

    return (\%data, $fn_found, $fn_hit);
}


#
# apply_baseline(data_ref, baseline_ref)
#
# Subtract the execution counts found in the baseline hash referenced by
# BASELINE_REF from actual data in DATA_REF.
#

sub apply_baseline($$)
{
    my %data_hash = %{$_[0]};
    my %base_hash = %{$_[1]};
    my $filename;
    my $testname;
    my $data;
    my $data_testdata;
    my $data_funcdata;
    my $data_checkdata;
    my $data_testfncdata;
    my $data_testbrdata;
    my $data_count;
    my $data_testfnccount;
    my $data_testbrcount;
    my $base;
    my $base_checkdata;
    my $base_sumfnccount;
    my $base_sumbrcount;
    my $base_count;
    my $sumcount;
    my $sumfnccount;
    my $sumbrcount;
    my $found;
    my $hit;
    my $fn_found;
    my $fn_hit;
    my $br_found;
    my $br_hit;

    foreach $filename (keys(%data_hash))
    {
        # Get data set for data and baseline
        $data = $data_hash{$filename};
        $base = $base_hash{$filename};

        # Skip data entries for which no base entry exists
        if (!defined($base))
        {
            next;
        }

        # Get set entries for data and baseline
        ($data_testdata, undef, $data_funcdata, $data_checkdata,
         $data_testfncdata, undef, $data_testbrdata) =
            get_info_entry($data);
        (undef, $base_count, undef, $base_checkdata, undef,
         $base_sumfnccount, undef, $base_sumbrcount) =
            get_info_entry($base);

        # Check for compatible checksums
        merge_checksums($data_checkdata, $base_checkdata, $filename);

        # sumcount has to be calculated anew
        $sumcount = {};
        $sumfnccount = {};
        $sumbrcount = {};

        # For each test case, subtract test specific counts
        foreach $testname (keys(%{$data_testdata}))
        {
            # Get counts of both data and baseline
            $data_count = $data_testdata->{$testname};
            $data_testfnccount = $data_testfncdata->{$testname};
            $data_testbrcount = $data_testbrdata->{$testname};

            ($data_count, undef, $hit) =
                subtract_counts($data_count, $base_count);
            ($data_testfnccount) =
                subtract_fnccounts($data_testfnccount,
                           $base_sumfnccount);
            ($data_testbrcount) =
                combine_brcount($data_testbrcount,
                         $base_sumbrcount, $BR_SUB);


            # Check whether this test case did hit any line at all
            if ($hit > 0)
            {
                # Write back resulting hash
                $data_testdata->{$testname} = $data_count;
                $data_testfncdata->{$testname} =
                    $data_testfnccount;
                $data_testbrdata->{$testname} =
                    $data_testbrcount;
            }
            else
            {
                # Delete test case which did not impact this
                # file
                delete($data_testdata->{$testname});
                delete($data_testfncdata->{$testname});
                delete($data_testbrdata->{$testname});
            }

            # Add counts to sum of counts
            ($sumcount, $found, $hit) =
                add_counts($sumcount, $data_count);
            ($sumfnccount, $fn_found, $fn_hit) =
                add_fnccount($sumfnccount, $data_testfnccount);
            ($sumbrcount, $br_found, $br_hit) =
                combine_brcount($sumbrcount, $data_testbrcount,
                        $BR_ADD);
        }

        # Write back resulting entry
        set_info_entry($data, $data_testdata, $sumcount, $data_funcdata,
                   $data_checkdata, $data_testfncdata, $sumfnccount,
                   $data_testbrdata, $sumbrcount, $found, $hit,
                   $fn_found, $fn_hit, $br_found, $br_hit);

        $data_hash{$filename} = $data;
    }

    return (\%data_hash);
}


#
# remove_unused_descriptions()
#
# Removes all test descriptions from the global hash %test_description which
# are not present in %info_data.
#

sub remove_unused_descriptions()
{
    my $filename;        # The current filename
    my %test_list;        # Hash containing found test names
    my $test_data;        # Reference to hash test_name -> count_data
    my $before;        # Initial number of descriptions
    my $after;        # Remaining number of descriptions

    $before = scalar(keys(%test_description));

    foreach $filename (keys(%info_data))
    {
        ($test_data) = get_info_entry($info_data{$filename});
        foreach (keys(%{$test_data}))
        {
            $test_list{$_} = "";
        }
    }

    # Remove descriptions for tests which are not in our list
    foreach (keys(%test_description))
    {
        if (!defined($test_list{$_}))
        {
            delete($test_description{$_});
        }
    }

    $after = scalar(keys(%test_description));
    if ($after < $before)
    {
        info("Removed ".($before - $after).
             " unused descriptions, $after remaining.\n");
    }
}


#
# apply_prefix(filename, prefix)
#
# If FILENAME begins with PREFIX, remove PREFIX from FILENAME and return
# resulting string, otherwise return FILENAME.
#

sub apply_prefix($$)
{
    my $filename = $_[0];
    my $prefix = $_[1];

    if (defined($prefix) && ($prefix ne ""))
    {
        if ($filename =~ /^\Q$prefix\E\/(.*)$/)
        {
            return substr($filename, length($prefix) + 1);
        }
    }

    return $filename;
}


#
# system_no_output(mode, parameters)
#
# Call an external program using PARAMETERS while suppressing depending on
# the value of MODE:
#
#   MODE & 1: suppress STDOUT
#   MODE & 2: suppress STDERR
#
# Return 0 on success, non-zero otherwise.
#

sub system_no_output($@)
{
    my $mode = shift;
    my $result;
    local *OLD_STDERR;
    local *OLD_STDOUT;

    # Save old stdout and stderr handles
    ($mode & 1) && open(OLD_STDOUT, ">>&", "STDOUT");
    ($mode & 2) && open(OLD_STDERR, ">>&", "STDERR");

    # Redirect to /dev/null
    ($mode & 1) && open(STDOUT, ">", "/dev/null");
    ($mode & 2) && open(STDERR, ">", "/dev/null");

    system(@_);
    $result = $?;

    # Close redirected handles
    ($mode & 1) && close(STDOUT);
    ($mode & 2) && close(STDERR);

    # Restore old handles
    ($mode & 1) && open(STDOUT, ">>&", "OLD_STDOUT");
    ($mode & 2) && open(STDERR, ">>&", "OLD_STDERR");

    return $result;
}


#
# read_config(filename)
#
# Read configuration file FILENAME and return a reference to a hash containing
# all valid key=value pairs found.
#

sub read_config($)
{
    my $filename = $_[0];
    my %result;
    my $key;
    my $value;
    local *HANDLE;

    if (!open(HANDLE, "<", $filename))
    {
        warn("WARNING: cannot read configuration file $filename\n");
        return undef;
    }
    while (<HANDLE>)
    {
        chomp;
        # Skip comments
        s/#.*//;
        # Remove leading blanks
        s/^\s+//;
        # Remove trailing blanks
        s/\s+$//;
        next unless length;
        ($key, $value) = split(/\s*=\s*/, $_, 2);
        if (defined($key) && defined($value))
        {
            $result{$key} = $value;
        }
        else
        {
            warn("WARNING: malformed statement in line $. ".
                 "of configuration file $filename\n");
        }
    }
    close(HANDLE);
    return \%result;
}


#
# apply_config(REF)
#
# REF is a reference to a hash containing the following mapping:
#
#   key_string => var_ref
#
# where KEY_STRING is a keyword and VAR_REF is a reference to an associated
# variable. If the global configuration hashes CONFIG or OPT_RC contain a value
# for keyword KEY_STRING, VAR_REF will be assigned the value for that keyword.
#

sub apply_config($)
{
    my $ref = $_[0];

    foreach (keys(%{$ref}))
    {
        if (defined($opt_rc{$_})) {
            ${$ref->{$_}} = $opt_rc{$_};
        } elsif (defined($config->{$_})) {
            ${$ref->{$_}} = $config->{$_};
        }
    }
}


#
# get_html_prolog(FILENAME)
#
# If FILENAME is defined, return contents of file. Otherwise return default
# HTML prolog. Die on error.
#

sub get_html_prolog($)
{
    my $filename = $_[0];
    my $result = "";

    if (defined($filename))
    {
        local *HANDLE;

        open(HANDLE, "<", $filename)
            or die("ERROR: cannot open html prolog $filename!\n");
        while (<HANDLE>)
        {
            $result .= $_;
        }
        close(HANDLE);
    }
    else
    {
        $result = <<END_OF_HTML
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">

<html lang="en">

<head>
  <meta http-equiv="Content-Type" content="text/html; charset=$charset">
  <title>\@pagetitle\@</title>
  <link rel="stylesheet" type="text/css" href="\@basedir\@gcov.css">
</head>

<body>

END_OF_HTML
        ;
    }

    return $result;
}


#
# get_html_epilog(FILENAME)
#
# If FILENAME is defined, return contents of file. Otherwise return default
# HTML epilog. Die on error.
#
sub get_html_epilog($)
{
    my $filename = $_[0];
    my $result = "";

    if (defined($filename))
    {
        local *HANDLE;

        open(HANDLE, "<", $filename)
            or die("ERROR: cannot open html epilog $filename!\n");
        while (<HANDLE>)
        {
            $result .= $_;
        }
        close(HANDLE);
    }
    else
    {
        $result = <<END_OF_HTML

</body>
</html>
END_OF_HTML
        ;
    }

    return $result;

}

sub warn_handler($)
{
    my ($msg) = @_;

    warn("$tool_name: $msg");
}

sub die_handler($)
{
    my ($msg) = @_;

    die("$tool_name: $msg");
}

#
# parse_ignore_errors(@ignore_errors)
#
# Parse user input about which errors to ignore.
#

sub parse_ignore_errors(@)
{
    my (@ignore_errors) = @_;
    my @items;
    my $item;

    return if (!@ignore_errors);

    foreach $item (@ignore_errors) {
        $item =~ s/\s//g;
        if ($item =~ /,/) {
            # Split and add comma-separated parameters
            push(@items, split(/,/, $item));
        } else {
            # Add single parameter
            push(@items, $item);
        }
    }
    foreach $item (@items) {
        my $item_id = $ERROR_ID{lc($item)};

        if (!defined($item_id)) {
            die("ERROR: unknown argument for --ignore-errors: ".
                "$item\n");
        }
        $ignore[$item_id] = 1;
    }
}

#
# rate(hit, found[, suffix, precision, width])
#
# Return the coverage rate [0..100] for HIT and FOUND values. 0 is only
# returned when HIT is 0. 100 is only returned when HIT equals FOUND.
# PRECISION specifies the precision of the result. SUFFIX defines a
# string that is appended to the result if FOUND is non-zero. Spaces
# are added to the start of the resulting string until it is at least WIDTH
# characters wide.
#

sub rate($$;$$$)
{
        my ($hit, $found, $suffix, $precision, $width) = @_;
        my $rate;

    # Assign defaults if necessary
        $precision    = 1    if (!defined($precision));
    $suffix        = ""    if (!defined($suffix));
    $width        = 0    if (!defined($width));

        return sprintf("%*s", $width, "-") if (!defined($found) || $found == 0);
        $rate = sprintf("%.*f", $precision, $hit * 100 / $found);

    # Adjust rates if necessary
        if ($rate == 0 && $hit > 0) {
        $rate = sprintf("%.*f", $precision, 1 / 10 ** $precision);
        } elsif ($rate == 100 && $hit != $found) {
        $rate = sprintf("%.*f", $precision, 100 - 1 / 10 ** $precision);
    }

    return sprintf("%*s", $width, $rate.$suffix);
}
