# remove_assigns.awk - replace "assign <lhs> = <rhs>;" with a BUFX2 instance.
# Genus merges the sign-extension flops of c_out and ties several output ports
# to one net with assign statements; in the layout that net then carries several
# pin labels (Assura LVS label shorts). One buffer per assign gives every port
# its own net. Usage: awk -f remove_assigns.awk in.v > out.v
/^[ \t]*assign[ \t]+[^=]+=[^;]+;[ \t]*$/ {
    line = $0
    sub(/^[ \t]*assign[ \t]+/, "", line); sub(/[ \t]*;[ \t]*$/, "", line)
    split(line, p, /[ \t]*=[ \t]*/)
    if (p[2] ~ /^[0-9]+'[bBhHdD]/) { print "ERROR constant assign: " $0 > "/dev/stderr"; exit 1 }
    printf "  BUFX2 FE_ASSIGN_BUF_%d (.A(%s), .Y(%s));\n", n++, p[2], p[1]
    next
}
{ print }
END { print "remove_assigns: replaced " n " assign statements" > "/dev/stderr" }
