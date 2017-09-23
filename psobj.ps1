#: 22 (SSH), 25 (SMTP), 53 (DNS; must be open for both tcp & udp), 80 (HTTP), 443 (HTTPS), 587 (SMTP submission), 993 (IMAP), 995 (POP) and 4190 (Sieve).
#inboundrules
$array = @()
$rules=[Pscustomobject]@{
    nsrname = "smtp" #becomes name of the rule, the description and the variable
    nsrdirection = "inbound"   #inbound or outbound
    nsrprotocol = "*"   #tcp,udp or *
    nsrport = 22
   nsrpriority = 110
}


