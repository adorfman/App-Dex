#!/usr/bin/env perl
use warnings;
use strict;
use Test::More;
use Test::Deep;
use App::Dex2;
use File::Temp;
use Test::MockModule;

my $commands_run = [];
my $mock_run3 = sub {
    my $cmd = shift;

    if ( ref($cmd) ) {
        diag "running: ". join(' ', @$cmd);
    }
    else {
        diag "running: $cmd"; 
    }

    push @$commands_run, $cmd;
};

my $mock = Test::MockModule->new('App::Dex2');
$mock->mock(run3 => $mock_run3 );


my $tests = [
    {
        content => [
            '---',
            'version: 2',
            'blocks:',
            '  - name: command_test',
            '    desc: Command Test',
            '    commands:',
            '      - exec: echo "hello world"'
        ],
        argv      => [qw|command_test|],
        commands =>  [
          'echo "hello world"'
        ], 
        title       => 'Ensure we find the correct block',
        line        => __LINE__,
    },
];

foreach my $test ( @{$tests} ) {
    my $file = File::Temp->new( unlink => 1 );

    foreach my $line ( @{$test->{content}} ) {
        print $file "$line\n";
    }
    close($file); # Write the file

    ok my $app = App::Dex2->new( config_file_names => [ $file->filename ], argv => $test->{argv} ), sprintf( "line %d: %s", $test->{line}, "Object Construction" );
    $app->run();

    #diag explain $commands_run;

    cmp_deeply $commands_run, $test->{commands}, sprintf( "line %d: %s", $test->{line}, $test->{title} ); 

    $commands_run = [];
}

done_testing();  
