#!/usr/bin/env perl
use warnings;
use strict;
use Cwd;
use Test::More;
use Test::Deep;
use App::Dex;
use File::Temp;
use Test::MockModule; 

my $tests = [
    {
        content => [
            '---',
            'version: 2',
            'vars:', 
            '  dir: "somedir"',  
            'blocks:',
            '  - name: command_test',
            '    desc: Command Test',
            '    commands:',
            '      - exec: echo "hello world in [%dir%]"'
        ],
        class     => 'App::Dex2',
        argv      => [qw|command_test|],
        commands =>  [
          'echo "hello world in somedir"'
        ], 
        title       => 'App::Dex2 config file',
        line        => __LINE__,
    },
    {
        content => [
            '---',
            '- name: command_test',
            '  desc: Command Test',
        ],
        class     => 'App::Dex',
        title       => 'App::Dex config file',
        line        => __LINE__,
    },
];

foreach my $test ( @{$tests} ) {
    my $file = File::Temp->new( unlink => 1 );

    my $path = $file->filename;

    foreach my $line ( @{$test->{content}} ) {
        print $file "$line\n";
    }
    close($file); # Write the file

    local @App::Dex::CONFIG_FILE_NAMES = ($path);

    my $app = App::Dex->load_version_from_config( argv => $test->{argv} );

    isa_ok($app, $test->{class});

    #my $run = $test->{run} || sub { $app->run(); };

    #$run->($app,$test);
    ##diag explain $commands_run;

    #cmp_deeply $commands_run, $test->{commands}, sprintf( "line %d: %s", $test->{line}, $test->{title} ); 

    #$commands_run = [];
}

done_testing(); 
