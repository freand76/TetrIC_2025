library IEEE;
use IEEE.std_logic_1164.all;

entity arb is
    port (bildreq,procdmemreq, procdmemreqend, ljudreq: in std_logic_vector(0 downto 0) ;
	  bildarb,procdmemarb, procdmemarbend, procimemarb, ljudarb : out std_logic_vector(0 downto 0));
end arb;

-- purpose: arbitrering av rambussen
architecture behaviour_arb of arb is
    
begin

    procdmemarbend <= "1" when procdmemreqend = "1" else "0";
    
    bildarb<="1" when bildreq="1" and procdmemreqend = "0" else "0";

    ljudarb <= "1" when bildreq = "0" and procdmemreqend = "0" and ljudreq = "1" else "0";
    
    procdmemarb<="1" when bildreq="0" and procdmemreq="1" and procdmemreqend = "0" and ljudreq = "0" else "0";

    procimemarb<="1" when bildreq="0" and procdmemreq="0" and procdmemreqend = "0" and ljudreq = "0" else "0";
    
end behaviour_arb;
