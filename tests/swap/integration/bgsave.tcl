start_server {tags {"swap bgsave"}} {
    set redis_host [srv 0 host]
    set redis_port [srv 0 port]

    r config set save "1 1"
    set load_handle0 [start_bg_complex_data $redis_host $redis_port 0 1000000]
    test {Detect write load to redis} {
        wait_for_condition 50 10000 {
            [r dbsize] > 1000
        } else {
            fail "Can't detect write load from background clients."
        }
    }
    r config set swap-debug-swapout-notify-delay-micro 100000

    for {set j 0} {$j < 10} {incr j} {
        test "check rdb generated by periodic bgsave round$j" {
            after 1000
            r debug reload nosave
            r ping
        }
    }

    r config set save ""
    waitForBgsave r

    for {set j 0} {$j < 10} {incr j} {
        test "check rdb generated by bgsave schedule round$j" {
            after 1000
            r bgrewriteaof
            r bgsave schedule
            waitForBgrewriteaof r
            after 120 ;# serverCron only schedule bgsave once in 100ms
            waitForBgsave r
            wait_for_condition 10 5000 {
                [s rdb_bgsave_in_progress] == 0
            } else {
                fail "Bgsave timeout."
            }
            r debug reload nosave
        }
    }

    stop_bg_complex_data $load_handle0
}

start_server {tags {"swap bgsave"}} {
    set redis_host [srv 0 host]
    set redis_port [srv 0 port]

    set load_handle0 [start_bg_complex_data $redis_host $redis_port 0 1000000]
    after 10000
    stop_bg_complex_data $load_handle0

    test "debug reload after bgsave" {
        r set k1 v1
        r swap.evict k1
        r bgsave
        r del k1
        r debug reload
        assert_equal [r get k1] {}
    }

}

