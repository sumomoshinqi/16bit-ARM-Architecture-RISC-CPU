movh r0,#aah
movl r0,#aah
mov r1,r0
movl r4,#ffh
movh r4,#0
lsli r2,[r0,#1]
and r3,r2,r1
str r2,[r4,#2]
ldr r4,[r4,#2]
ori r4,#f0h