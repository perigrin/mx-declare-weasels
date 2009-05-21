I was reading a [blog post][1] recently that mentioned the [Dawkins Weasel
program][2]. I have always wanted to play around with [Genetic Algorithms][3]
and this one seemed simple enough to hack at for a few hours. Four hours later
I think I have something that can illustrate Modern Moose nicely ( Spacecataz
this is specifically for you, seduce you back away from Python). NOTE: I have
re-arranged some stuff to make this discussion a little easier. The [source
code][8] will show the right order and will run properly.


    #!/usr/bin/env perl
    use 5.10.0;
    use MooseX::Declare;

Like any good perl modern script we start out with a `#!` line, state that
we're gonna use a Modern Perl (5.10+), and we're gonna use some of the new
sugary syntax from [`MooseX::Declare`][3]

Now in the [code I pilfered the algorithm][4] from we have some global
parameters. [Matt Trout][11] likes to call Singleton objects "God" objects, so we'll
just borrow that nomenclature here. (The irony of having evolutionary code
need a GOD doesn't hurt either).

    class GOD {
        use constant TARGET        => 'METHINKS IT IS LIKE A WEASEL';
        use constant MUTATION_RATE => 0.09;

        sub DEFAULT_STRING() { join '', map { RANDOM_LETTER() } 0..length TARGET }
        sub RANDOM_LETTER() { ( 'A' .. 'Z', ' ' )[ rand(27) ] }
    }

`DEFAULT_STRING` and `RANDOM_LETTER` are some utility methods we'll use in a
bit.

So now that we have God we can create the `World`. Our `World` is basically a
container for evolving generations of objects (in our case `Weasels`). We have
a small world, it can only hold 50 `Weasels` at a time.

    class World {
        use constant SIZE => 50;

Our world is also a harsh mistress, there can only be one generation alive at
a time. (Though all is not lost as we'll see, `Weasels` can worship their
ancestors). We keep an ArrayRef of Weasels around. 

        use MooseX::AttributeHelpers;
        
        has current_generation => (
            isa        => 'ArrayRef[Weasel]',
            is         => 'rw',
            auto_deref => 1,
            builder    => 'first_generation',
            metaclass  => 'Collection::List',
            provides   => {
                first => 'best',
            }
        );

We're useing [`MooseX::AttributeHelpers`][5] to provide us with a simple
helper method that returns the "best" Weasel in each generation. We know its
the best because our world keeps `Weasels` sorted by their fitness.

        sub _generate (&) {
            [ sort { $a->fitness <=> $b->fitness } map { $_[0]->() } 1 .. SIZE ];
        }
        
        method first_generation {  _generate { Weasel->new }    }
        method new_generation {
             $self->current_generation( _generate { $self->best->spawn } );
        }

There are two times we want to generate a new generation of `Weasels`, at the
dawn of the world when the `current_generation` attribute is first initalized,
and when we call new_generation. At initalization we create an Ur-Weasel,
every other time we let the best `Weasel` of it's generation breed. It's good
to be fit.

So now that we've covered how generations work, the Way the world `run`'s
should be obvious. Keep generating `new_generation`s until the [Kwisatz
Haderach][6] is born.

        method run {
            $self->new_generation() until $self->perfect_offspring;
        }

How do we know when we have perfect offspring? When the best of our generation
is perfect.

        method perfect_offspring { $self->best->perfect }

Finally so that the runtime isn't totally boring waiting for the world to end,
we use a [method modifier][7] to tack on some output letting us know who the
best in each generation is.

        after new_generation { say $self->best->to_string };
    }

So let's look at the population of our world. Ah the `Weasel`, the most
quintessential of `GOD`'s creations. `Weasel`'s do one thing in life, they
breed mutants. So our Weasel class composes the [Role][9]
`NonLockingMutations` which we'll gloss over for a bit and just say "`Weasels`
can evolve".

    class Weasel with NonLockingMutations {

Now I said before that `Weasel`s have a strong sense of ancestory, even though
the `World` only knows about one generation of `Weasel` at a time, each weasel
knows exactly who it's parent was, and what generation they belong to.
        
        has parent     => ( isa => 'Weasel', is => 'ro', );
        has generation => ( isa => 'Int',    is => 'rw', builder => 'my_generation' );

        method my_generation {
            return 0 unless $self->parent;
            $self->parent->generation + 1;
        }

They also have a little genetic string. Which they inherit from their parent
(unless they're the Ur-`Weasel` in which case they get it from `GOD`).
        
        has string     => ( isa => 'Str',    is => 'ro', lazy_build => 1 );
        
        method _build_string {
            return $self->inherit_string if $self->parent;
            return GOD::DEFAULT_STRING;
        }

Finally `Weasel`s can breed, they each have one child and teach it who its
parent is, and they know how to tell the `World` about themselves.

        method spawn { Weasel->new( parent => $self ) }
        
        method to_string {
            "${\sprintf('%04d', $self->generation)}:${ \$self->string } (${\sprintf('%02d', $self->fitness)})";
        }
    }

Now we get to the interesting part of this, the reason we created our own
little universe. `Weasel`s would never become perfect if they couldn't Mutate.


    role Mutations {
        requires qw(string parent mutate);

In our universe fitness is determined by the [Levenshtein][10] distance of the
`Weasel`s string from `GOD`'s target.

        use Text::LevenshteinXS qw(distance);
        
        has fitness => ( isa => 'Int', is => 'rw', lazy_build => 1 );
        
        method _build_fitness { distance( $self->string, GOD::TARGET() ) }    

We know we're perfect when our distance from `GOD`s `TARGET` (our fitness) is
0.

        method perfect { $self->fitness == 0 }

Mutations are also where we inherit strings from our parents. Strings are
never inherited cleanly, there's always a chance at mutation. That chance
however depends on the mutation mechanism we're using

        method inherit_string {
            return join '', map { $self->mutate($_) }
                0..length $self->parent->string;
        }
    }

Mutations in our world come in two flavors, Non Locking Mutations mean every
character is free to mutate no matter if it already matches the corresponding
character in the `TARGET`. Locking Mutations don't change characters that
already match.

Here are the implementations for each, they're pretty straight forward, and
mostly the same. If we haven't been hit by a cosmic beam (ie a random number
is less than `GOD`s `MUTATION_RATE`), return that character unmodified.
Otherwise return a new random character.

    role NonLockingMutations with Mutations {
        sub mutate {
            my $target = substr($_[0]->parent->string, $_[1], 1);
            return $target unless rand() < GOD::MUTATION_RATE;
            return GOD::RANDOM_LETTER;
        }
    }

The only thing that `LockingMutations` changes on this is if we already match
`GOD`s `TARGET`, return the current character.

    role LockingMutations with Mutations {
        sub mutate {        
            my $target = substr($_[0]->parent->string, $_[1], 1);
            return $target if $target eq substr(GOD::TARGET, $_[1],1);
            return $target unless rand() < GOD::MUTATION_RATE;
            return GOD::RANDOM_LETTER;
        }
    }

That's it, everything is implemented. We start the world running and see
our results

    World->new->run;


[1]: http://spacecataz1663.blogspot.com/2009/05/shhhh-im-having-affair.html
[2]: http://en.wikipedia.org/wiki/Weasel_program
[3]: http://search.cpan.org/dist/MooseX-Declare
[4]: http://www.nmsr.org/weasel.htm
[5]: http://search.cpan.org/dist/MooseX-AttributeHelpers
[6]: http://en.wikipedia.org/wiki/Kwisatz_Haderach
[7]: http://search.cpan.org/dist/Moose/lib/Moose/Manual/MethodModifiers.pod
[8]: http://github.com/perigrin/mx-declare-weasels
[9]: http://search.cpan.org/dist/Moose/lib/Moose/Manual/Roles.pod
[10]: http://en.wikipedia.org/wiki/Levenshtein_distance
[11]: http://www.shadowcat.co.uk/blog/matt-s-trout/