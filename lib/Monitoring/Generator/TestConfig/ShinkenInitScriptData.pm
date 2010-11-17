package # hidden from cpan
    Monitoring::Generator::TestConfig::ShinkenInitScriptData;

use strict;
use warnings;

########################################

=over 4

=item get_init_script

    returns the init script source

    adapted from the nagios debian package

=back

=cut

sub get_init_script {
    my $self      = shift;
    my $prefix    = shift;
    my $binary    = shift;
    our $initsource;
    if(!defined $initsource) {
       while(my $line = <DATA>) { $initsource .= $line; }
    }

    my $binpath = $binary;
    $binpath =~ s/^(.*)\/.*$/$1/mx;

    my $initscript = $initsource;
    $initscript =~ s/__PREFIX__/$prefix/gmx;
    $initscript =~ s/__BIN__/$binpath/gmx;
    return($initscript);
}

1;

__DATA__
#!/bin/sh

### BEGIN INIT INFO
# Provides:          shinken
# Required-Start:    $local_fs
# Required-Stop:     $local_fs
# Default-Start:     2 3 4 5
# Default-Stop:      S 0 1 6
# Short-Description: shinken
# Description:       shinken monitoring daemon
### END INIT INFO

NAME="shinken"
SCRIPTNAME=$0
CMD=$1
shift
SUBMODULES=$*
AVAIL_MODULES="scheduler poller reactionner broker arbiter"
BIN="__BIN__"
VAR="__PREFIX__/var"
ETC="__PREFIX__/etc"

usage() {
    echo "Usage: $SCRIPTNAME {start|stop|restart|status} [ <$AVAIL_MODULES> ]" >&2
    exit 3
}

DEBUG=0
if [ -z "$SUBMODULES" ]; then
    SUBMODULES=$AVAIL_MODULES
else
    # verify given modules
    for mod1 in $SUBMODULES; do
        found=0
        for mod2 in $AVAIL_MODULES; do
            [ $mod1 = $mod2 ] && found=1;
            [ $mod1 = "-d" ]  && found=1 && DEBUG=1;
        done
        [ $found = 0 ] && usage
    done
fi


# Read configuration variable file if it is present
[ -r /etc/default/$NAME ] && . /etc/default/$NAME

# Load the VERBOSE setting and other rcS variables
[ -f /etc/default/rcS ] && . /etc/default/rcS

# Define LSB log_* functions.
. /lib/lsb/init-functions

#
# return the pid for a submodule
#
getmodpid() {
    mod=$1
    pidfile="$VAR/${mod}d.pid"
    if [ $mod != 'arbiter' ]; then
        pidfile="$VAR/shinken.pid"
    fi
    if [ -s $pidfile ]; then
        cat $pidfile
    fi
}

#
# stop modules
#
do_stop() {
    ok=0
    fail=0
    echo "stoping $NAME...";
    for mod in $SUBMODULES; do
        pid=`getmodpid $mod`;
        printf "%-15s: " $mod
        if [ ! -z $pid ]; then
            for cpid in $(ps -aef | grep $pid | grep "shinken-" | awk '{print $2}'); do
                kill $cpid > /dev/null 2>&1
            done
        fi
        echo "done"
    done
    return 0
}


#
# Display status
#
do_status() {
    ok=0
    fail=0
    echo "status $NAME: ";
    for mod in $SUBMODULES; do
        pid=`getmodpid $mod`;
        printf "%-15s: " $mod
        if [ ! -z $pid ]; then
            ps -p $pid >/dev/null 2>&1
            if [ $? = 0 ]; then
                echo "RUNNING (pid $pid)"
                ok=$((ok+1))
            else
                echo "NOT RUNNING"
                fail=$((fail+1))
            fi
        else
            echo "NOT RUNNING"
            fail=$((fail+1))
        fi
    done
    if [ $fail -gt 0 ]; then
        return 1
    fi
    return 0
}

#
# start our modules
#
do_start() {
    echo "starting $NAME: ";
    for mod in $SUBMODULES; do
        printf "%-15s: " $mod
        DEBUGCMD=""
        [ $DEBUG = 1 ] && DEBUGCMD="--debug $VAR/${mod}-debug.log"
        if [ $mod != 'arbiter' ]; then
            output=`$BIN/shinken-${mod} -d -c $ETC/${mod}d.cfg $DEBUGCMD 2>&1`
        else
            output=`$BIN/shinken-${mod} -d -c $ETC/../shinken.cfg -c $ETC/shinken-specific.cfg $DEBUGCMD 2>&1`
        fi
        if [ $? = 0 ]; then
            echo "OK"
        else
            echo "FAILED $output" | head -1  # only show first line of error output...
        fi
    done
}

#
# check for our command
#
case "$CMD" in
  start)
    [ "$VERBOSE" != no ] && log_daemon_msg "Starting $NAME"
    do_start
    do_status > /dev/null 2>&1
    case "$?" in
        0) [ "$VERBOSE" != no ] && log_end_msg 0 ;;
        1) [ "$VERBOSE" != no ] && log_end_msg 1 ;;
    esac
    ;;
  stop)
    [ "$VERBOSE" != no ] && log_daemon_msg "Stopping $NAME"
    do_stop
    do_status > /dev/null 2>&1
    case "$?" in
        0) [ "$VERBOSE" != no ] && log_end_msg 0 ;;
        1) [ "$VERBOSE" != no ] && log_end_msg 1 ;;
    esac
    ;;
  restart)
    [ "$VERBOSE" != no ] && log_daemon_msg "Restarting $NAME"
    do_stop
    do_status > /dev/null 2>&1
    case "$?" in
      0)
        do_start
        do_status > /dev/null 2>&1
        case "$?" in
            0) log_end_msg 0 ;;
            *) log_end_msg 1 ;; # Failed to start
        esac
        ;;
      *)
        # Failed to stop
        log_end_msg 1
        ;;
    esac
    ;;
  status)
    do_status
    ;;
  *)
    usage;
    ;;
esac
