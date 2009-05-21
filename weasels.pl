#!/usr/bin/env perl
use 5.10.0;
use MooseX::Declare;
use Text::LevenshteinXS qw(distance);
use MooseX::AttributeHelpers;

class GOD { # Ironic Isn't It.
    use constant TARGET        => 'METHINKS IT IS LIKE A WEASEL';
    use constant MUTATION_RATE => 0.09;

    sub DEFAULT_STRING() { join '', map { RANDOM_LETTER() } 0..length TARGET }
    sub RANDOM_LETTER() { ( 'A' .. 'Z', ' ' )[ rand(27) ] }
}


role Mutations {
    requires qw(string parent);
    has fitness => ( isa => 'Int', is => 'rw', lazy_build => 1 );
    method _build_fitness { ::distance( $self->string, GOD::TARGET() ) }    
    
    method inherit_string {
        return join '', map { $self->mutate($_) }
            0..length $self->parent->string;
    }
}

role NonLockingMutations with Mutations {
    sub mutate {
        my $target = substr($_[0]->parent->string, $_[1], 1);
        return $target unless rand() < GOD::MUTATION_RATE;
        return GOD::RANDOM_LETTER;
    }
}

role LockingMutations with Mutations {
    sub mutate {        
        my $target = substr($_[0]->parent->string, $_[1], 1);
        return $target if $target eq substr(GOD::TARGET, $_[1],1);
        return $target unless rand() < GOD::MUTATION_RATE;
        return GOD::RANDOM_LETTER;
    }
}

class Weasel with NonLockingMutations {

    has parent     => ( isa => 'Weasel', is => 'ro', );
    has string     => ( isa => 'Str',    is => 'ro', lazy_build => 1 );
    has generation => ( isa => 'Int',    is => 'rw', lazy_build => 1 );

    method _build_string {
        return $self->inherit_string if $self->parent;
        return GOD::DEFAULT_STRING;
    }

    method _build_generation {
        return 0 unless $self->parent;
        $self->parent->generation + 1;
    }

    method spawn { Weasel->new( parent => $self ) }

    method to_string {
        "${\sprintf('%04d', $self->generation)}:${ \$self->string } (${\sprintf('%02d', $self->fitness)})";
    }

}

class World {
    use constant SIZE => 50;
    
    sub _generate (&) {
        [ sort { $a->fitness <=> $b->fitness } map { $_[0]->() } 1 .. SIZE ];
    }

    has current_generation => (
        isa        => 'ArrayRef[Weasel]',
        is         => 'rw',
        auto_deref => 1,
        lazy_build => 1,
        builder    => 'first_generation',
        metaclass  => 'Collection::List',
        provides   => {
            first => 'best',
        }
    );

    method first_generation {  _generate { Weasel->new }    }

    method new_generation {
         $self->current_generation( _generate { $self->best->spawn } );
    }

    method perfect_offspring { $self->best->fitness == 0 }

    method run {
        $self->new_generation() until $self->perfect_offspring;
        $self->best->to_string;
    }

    after new_generation { say $self->best->to_string };
}


World->new->run;
