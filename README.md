# NAME

Runner::Init 

# VERSION

Version 0.01

# SYNOPSIS

This is a base class for Runner::MCE and Runner:Threads. You should not need to call this module directly.

# EXPORT

# VARIABLES

## infile

File of commands separated by newline. The command 'wait' indicates all previous commands should finish before starting the next one.

## outdir

Directory to write out files and logs.

## logdir

Pattern to use to write out logs directory. Defaults to outdir/prunner\_current\_date\_time/log1 .. log2 .. log3.

## procs

Total number of running children allowed at any time. Defaults to 10. The command 'wait' can be used to have a variable number of children running. It is best to wrap this script in a slurm job to not overuse resources. This isn't used within this module, but passed off to mcerunner/parallelrunner.

# Internal VARIABLES

You shouldn't be calling these directly.

# Subroutines

## run\_commands\_threads

Start the thread, run the command, and finish the thread

## run\_commands\_mce

MCE knows which subcommand to use from Runner/MCE - object mce

## \_log\_commands

Log the commands run them. Cat stdout/err with IO::Select so we hopefully don't break things.

This example was just about 100% from the following perlmonks discussions.

http://www.perlmonks.org/?node\_id=151886

You can use the script at the top to test the runner. Just download it, make it executable, and put it in the infile as 

perl command.pl 1
perl command.pl 2
\#so on and so forth

# AUTHOR

Jillian Rowe, `<jillian.e.rowe at gmail.com>`

# BUGS

Please report any bugs or feature requests to `bug-runner-init at rt.cpan.org`, or through
the web interface at [http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Runner-Init](http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Runner-Init).  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

# SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Runner::Init

You can also look for information at:

- RT: CPAN's request tracker (report bugs here)

    [http://rt.cpan.org/NoAuth/Bugs.html?Dist=Runner-Init](http://rt.cpan.org/NoAuth/Bugs.html?Dist=Runner-Init)

- AnnoCPAN: Annotated CPAN documentation

    [http://annocpan.org/dist/Runner-Init](http://annocpan.org/dist/Runner-Init)

- CPAN Ratings

    [http://cpanratings.perl.org/d/Runner-Init](http://cpanratings.perl.org/d/Runner-Init)

- Search CPAN

    [http://search.cpan.org/dist/Runner-Init/](http://search.cpan.org/dist/Runner-Init/)

# ACKNOWLEDGEMENTS

This module was originally developed at and for Weill Cornell Medical College in Qatar. With approval from WCMC-Q, this information was generalized and put on github, for which the authors would like to express their gratitude.

# LICENSE AND COPYRIGHT

Copyright 2014 Jillian Rowe.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

[http://www.perlfoundation.org/artistic\_license\_2\_0](http://www.perlfoundation.org/artistic_license_2_0)

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
