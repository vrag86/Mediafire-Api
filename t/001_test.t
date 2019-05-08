#
#===============================================================================
#
#         FILE: 001_test.t
#
#  DESCRIPTION: 
#
#        FILES: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: YOUR NAME (), 
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 20.04.2019 21:40:06
#     REVISION: ---
#===============================================================================

use utf8;
use strict;
use warnings;
use File::Spec;

my $CURR_DIR;
BEGIN {
    $CURR_DIR = File::Spec->curdir;
}

use lib File::Spec->catdir($CURR_DIR, './lib');

use Test::More 'no_plan';                      # last test to print

use_ok('Mediafire::Api');

my $LOGIN               = $ENV{MEDIAFIRE_LOGIN};
my $PASSWORD            = $ENV{MEDIAFIRE_PASSWORD};
my $UPLOAD_FILE         = File::Spec->catfile($CURR_DIR, 't', 'test_upload3.f');


SKIP: {
    if (not $LOGIN) {
        skip "Variable ENV{MEDIAFIRE_LOGIN} not set. Skip test";
    }
    if (not $PASSWORD) {
        skip "Variable ENV{MEDIAFIRE_PASSWORD} not set. Skip test";
    }

    # Login to mediafire
    my $mediafire = eval {
        testLogin($LOGIN, $PASSWORD);
    };
    if ($@) {
        skip $@;
    }

    testUploadFile($mediafire, $UPLOAD_FILE);

};


sub testLogin {
    my ($login, $password) = @_;
    my $mediafire = Mediafire::Api->new();
    my $login_res = $mediafire->login(
        -login          => $login,
        -password       => $password,
    );
    ok($login_res, 'Test login success');

    return $mediafire;
}

sub testUploadFile {
    my ($mediafire, $file) = @_;
    my $upload_file = $mediafire->uploadFile(
        -file           => $file,
    );
}


