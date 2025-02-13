package App::Dex;
use Moo;
use List::Util qw( first );
use YAML::PP qw( LoadFile );
use IPC::Run3;

our $VERSION = '0.002003';

has argv => (
    is      => 'ro', 
    default => sub { [] }
);


my @CONFIG_FILE_NAMES = qw( dex.yaml .dex.yaml );

has config_file => (
    is      => 'ro',
    isa     => sub { die "Config file ".$_[0]." not found" unless $_[0] && -e $_[0] },
    lazy    => 1,
    builder => '_find_config_file'

);

sub find_config_file {
    my ($class, @locations) = @_;

    return $ENV{DEX_FILE} if $ENV{DEX_FILE}; 

    return (first { -e $_ } @locations);
}

sub _find_config_file {
    my $self = shift; 

    return $self->find_config_file(@{$self->config_file_names});
}

has config_file_names => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        return [ @CONFIG_FILE_NAMES ],
    },
);

has config => (
    is      => 'ro',
    lazy    => 1,
    builder => sub {
        LoadFile shift->config_file;
    },
);

has menu => (
    is      => 'ro',
    lazy    => 1,
    builder => sub {
        my ( $self ) = @_;
        return [ $self->_menu_data( $self->config, 0 ) ];
    }
);

sub _menu_data {
    my ( $self, $config, $depth ) = @_;

    my @menu;
    foreach my $block ( @{$config} ) {
        push @menu, {
            name  => $block->{name},
            desc  => $block->{desc},
            depth => $depth,
        };
        if ( $block->{children} ) {
            push @menu, $self->_menu_data($block->{children}, $depth + 1);

        }
    }
    return @menu;
}

sub display_menu {
    my ( $self, $menu ) = @_;

    $menu = $self->menu unless $menu;

    foreach my $item ( @{$menu} ) {
        printf( "%s%-24s: %s\n", " " x ( 4 * $item->{depth} ), $item->{name}, $item->{desc}  );
    }
}

sub resolve_block {
    my ( $self, $path ) = @_;

    return $self->_resolve_block( $path, $self->config );
}

sub _resolve_block {
    my ( $self, $path, $config ) = @_;

    my $block;
    while ( defined ( my $segment = shift @{$path} ) ) {
        $block = first { $_->{name} eq $segment } @{$config};

        return undef unless $block;

        if ( @{$path} ) {
            $config = $block->{children};
            next;
        }
    }
    return $block;
}

sub process_block {
    my ( $self, $block ) = @_;

    if ( $block->{shell} ) {
        _run_block_shell( $block );
    }
}

sub _run_block_shell {
    my ( $block ) = @_;

    foreach my $command ( @{$block->{shell}} ) {
        run3( $command );
    }
}

sub load_version_from_cfg {
    my ( $class, %params ) = @_;

    my $config_file = $class->find_config_file(@CONFIG_FILE_NAMES);
    my $config      = LoadFile $config_file;

    if ( ref($config) eq 'ARRAY' ) {
        return App::Dex->new( config_file => $config_file,  config => $config, %params );
    }
    elsif (ref($config) eq 'HASH' and $config->{version} == 2 ) {
        require App::Dex2;

        return App::Dex2->new( config_file => $config_file,  config => $config, %params ); 
    }  

}

sub run {
    my ( $self ) = @_;

    my @argv = @{$self->argv};

    if ( @argv && ( $argv[0] eq '--help' || $argv[0] eq '-h' ) ) {
        pod2usage( -verbose => 2 );
    }

    # Throw an error if we couldn't find a config file.
    try { $self->config_file } catch { die "Error: No config file found.\n" };

    if ( @argv ) {
        my $block = $self->resolve_block( [ @argv ] );

        if ( ! $block ) {
            if ( my $fallback = $ENV{DEX_FALLBACK_CMD} || $self->config->{fallback} ) {
                exec $fallback, @argv;
            } else {
                print STDERR "Error: No such command.\n\n";
                $self->display_menu;
                exit -1;
            }
        }

        $self->process_block( $block );
    } else {
        $self->display_menu;
    }
 

} 

1;

__END__

=encoding utf8

=head1 NAME

App::dex - Directory Execute

=head1 DESCRIPTION

B<dex> provides a command line utility for managing directory-specific commands.

=head1 USAGE

    dex                    - Display the menu
    dex command            - Run a command
    dex command subcommand - Run a sub command

Create a file called C<dex.yaml> or C<.dex.yaml> and define commands to be run.

=head1 DEX FILE SPECIFICATION

This is an example dex file.

    - name: build
      desc: "Run through the build process, including testing."
      shell:
        - ./fatpack.sh
        - dzil test
        - dzil build
    - name: test
      desc: "Just test the changes"
      shell:
        - dzil test
    - name: release
      desc: "Publish App::Dex to CPAN"
      shell:
        - dzil release
    - name: clean
      desc: "Remove artifacts"
      shell:
        - dzil clean
    - name: authordeps
      desc: "Install distzilla and dependencies"
      shell:
        - cpanm Dist::Zilla
        - dzil authordeps --missing | cpanm
        - dzil listdeps --develop --missing | cpanm

When running the command dex, a menu will display:

    $ dex
    build                   : Run through the build process, including testing.
    test                    : Just test the changes
    release                 : Publish App::Dex to CPAN
    clean                   : Remove artifacts
    authordeps              : Install distzilla and dependencies

To execute the build command run C<dex build>.

=head2 SUBCOMMANDS

Commands can be grouped to logically organize them, for example:

    - name: foo
      desc: "Foo command"
      children:
        - name: bar
          desc: "Bar subcommand"
          shell:
            - echo "Ran the command!"

The menu for this would show the relationship:

    $ dex
    foo                     : Foo command
        bar                     : Bar subcommand

To execute the command one would run C<dex foo bar>.


=head1 FALLBACK COMMAND

When dex doesn't understand the command it will give an error and display the menu. It
can be configured to allow another program to try to execute the command.

Set the environment variable C<DEX_FALLBACK_CMD> to the command you would like to run
instead.

=head1 AUTHOR

Kaitlyn Parkhurst (SymKat) I<E<lt>symkat@symkat.comE<gt>> ( Blog: L<http://symkat.com/> )

=head1 CONTRIBUTORS

=head1 SPONSORS

=head1 COPYRIGHT

Copyright (c) 2019 the App::dex L</AUTHOR>, L</CONTRIBUTORS>, and L</SPONSORS> as listed above.

=head1 LICENSE

This library is free software and may be distributed under the same terms as perl itself.

=head2 AVAILABILITY

The most current version of App::dec can be found at L<https://github.com/symkat/App-dex>
