# -*- Mode: perl; indent-tabs-mode: nil -*-
# 
# The contents of this file are subject to the Mozilla Public
# License Version 1.1 (the "License"); you may not use this file
# except in compliance with the License. You may obtain a copy of
# the License at http://www.mozilla.org/MPL/
# 
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
# implied. See the License for the specific language governing
# rights and limitations under the License.
# 
# The Original Code are the Bugzilla Tests.
# 
# The Initial Developer of the Original Code is Zach Lipton
# Portions created by Zach Lipton are 
# Copyright (C) 2001 Zach Lipton.  All
# Rights Reserved.
# 
# Contributor(s): Zach Lipton <zach@zachlipton.com>
#                 Joel Peshkin <bugreport@peshkin.net>


package Support::Files;

use Bugzilla;

use File::Find;

use constant IGNORE => qw(
    Bugzilla/DuoWeb.pm
);

@additional_files = ();

@files = glob('*');
my @extension_paths = map { $_->package_dir } @{ Bugzilla->extensions };
find(sub { push(@files, $File::Find::name) if $_ =~ /\.pm$/;}, 'Bugzilla', @extension_paths);
push(@files, 'extensions/create.pl');

my @extensions = glob('extensions/*');
foreach my $extension (@extensions) {
    # Skip disabled extensions
    next if -e "$extension/disabled";

    find(sub { push(@files, $File::Find::name) if $_ =~ /\.pm$/;}, $extension);
}

sub isTestingFile {
    my ($file) = @_;
    my $exclude;

    foreach my $ignore (IGNORE) {
        return undef if $ignore eq $file;
    }

    if ($file =~ /\.cgi$|\.pl$|\.pm$/) {
        return 1;
    }
    my $additional;
    foreach $additional (@additional_files) {
        if ($file eq $additional) { return 1; }
    }
    return undef;
}

foreach $currentfile (@files) {
    if (isTestingFile($currentfile)) {
        push(@testitems,$currentfile);
    }
}


1;
