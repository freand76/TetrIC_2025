library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

entity alu is
    
    port (in0, in1 : in std_logic_vector(31 downto 0);
	  alucontrol : in std_logic_vector(4 downto 0);
	  grafix : in std_logic_vector(31 downto 0);
	  joystick : in std_logic_vector(7 downto 0);
	  modplayer : in std_logic_vector(31 downto 0);
	  clk : in std_logic;
	  reset : in std_logic_vector(0 downto 0);
	  out0 : out std_logic_vector(31 downto 0);
	  zero : out std_logic_vector(0 downto 0);
	  overflowout : out std_logic_vector(0 downto 0));
end alu;

architecture alu_behavioral of alu is 

    signal setzero, setoverflow, setaritmetico : std_logic_vector(0 downto 0);
    signal delayedzero, overflow, aritmetico : std_logic_vector(0 downto 0);

begin  -- alu_behavioral
    
    process(in0, in1, alucontrol,grafix, aritmetico, overflow,
	    delayedzero, joystick, modplayer)
						
    variable add : std_logic_vector(32 downto 0);  -- vector used for add operations
    variable sub : std_logic_vector(32 downto 0);  -- vector used for sub operations
    variable res : std_logic_vector(31 downto 0);
    variable ones : std_logic_vector(31 downto 0); --:= (others => '1');
    variable zeroes : std_logic_vector(31 downto 0); --:= (others => '0');    

    begin
	add := ("0" & in0) + ("0" & in1);
	sub := ("0" & in0) - ("0" & in1);
	ones := (others => '1');
	zeroes := (others => '0');
	res := zeroes;
	setoverflow <= "0";
	setaritmetico <= "0";
	zero <= "1";
	overflowout <= "0";
	setzero <= "1";
	case alucontrol is
	    when "00000" => res := zeroes;  --nop
	    when "00011" => res := in0;  --jr, jalr
	    when "01111" => res := in1(15 downto 0) & "0000000000000000";  --lui  ändrad av mch010227,bytt mot srav
	    when "01000" => case in1(10 downto 6) is  --sll
		when "00000" => res := in0;
		when "00001" => res := in0(30 downto 0) & zeroes(0);
		when "00010" => res := in0(29 downto 0) & zeroes(1 downto 0);
		when "00011" => res := in0(28 downto 0) & zeroes(2 downto 0);
		when "00100" => res := in0(27 downto 0) & zeroes(3 downto 0);
		when "00101" => res := in0(26 downto 0) & zeroes(4 downto 0);
		when "00110" => res := in0(25 downto 0) & zeroes(5 downto 0);
		when "00111" => res := in0(24 downto 0) & zeroes(6 downto 0);
		when "01000" => res := in0(23 downto 0) & zeroes(7 downto 0); 
		when "01001" => res := in0(22 downto 0) & zeroes(8 downto 0);
		when "01010" => res := in0(21 downto 0) & zeroes(9 downto 0);
		when "01011" => res := in0(20 downto 0) & zeroes(10 downto 0);
		when "01100" => res := in0(19 downto 0) & zeroes(11 downto 0);
		when "01101" => res := in0(18 downto 0) & zeroes(12 downto 0);
		when "01110" => res := in0(17 downto 0) & zeroes(13 downto 0);
		when "01111" => res := in0(16 downto 0) & zeroes(14 downto 0);
		when "10000" => res := in0(15 downto 0) & zeroes(15 downto 0);
		when "10001" => res := in0(14 downto 0) & zeroes(16 downto 0);
		when "10010" => res := in0(13 downto 0) & zeroes(17 downto 0);
		when "10011" => res := in0(12 downto 0) & zeroes(18 downto 0);
		when "10100" => res := in0(11 downto 0) & zeroes(19 downto 0);
		when "10101" => res := in0(10 downto 0) & zeroes(20 downto 0);
		when "10110" => res := in0(9 downto 0) & zeroes(21 downto 0);
		when "10111" => res := in0(8 downto 0) & zeroes(22 downto 0); 
		when "11000" => res := in0(7 downto 0) & zeroes(23 downto 0);
		when "11001" => res := in0(6 downto 0) & zeroes(24 downto 0);
		when "11010" => res := in0(5 downto 0) & zeroes(25 downto 0);
		when "11011" => res := in0(4 downto 0) & zeroes(26 downto 0);
		when "11100" => res := in0(3 downto 0) & zeroes(27 downto 0);
		when "11101" => res := in0(2 downto 0) & zeroes(28 downto 0);
		when "11110" => res := in0(1 downto 0) & zeroes(29 downto 0);
		when "11111" => res := in0(0) & zeroes(30 downto 0);	
		when others => null;
	    end case;
	    when "01010" => case in1(10 downto 6) is  --srl
		when "00000" => res := in0;
		when "00001" => res := zeroes(0) & in0(31 downto 1);
		when "00010" => res := zeroes(1 downto 0) & in0(31 downto 2);
		when "00011" => res := zeroes(2 downto 0) & in0(31 downto 3);
		when "00100" => res := zeroes(3 downto 0) & in0(31 downto 4);
		when "00101" => res := zeroes(4 downto 0) & in0(31 downto 5);
		when "00110" => res := zeroes(5 downto 0) & in0(31 downto 6);
		when "00111" => res := zeroes(6 downto 0) & in0(31 downto 7);
		when "01000" => res := zeroes(7 downto 0) & in0(31 downto 8);
		when "01001" => res := zeroes(8 downto 0) & in0(31 downto 9);
		when "01010" => res := zeroes(9 downto 0) & in0(31 downto 10);
		when "01011" => res := zeroes(10 downto 0) & in0(31 downto 11);
		when "01100" => res := zeroes(11 downto 0) & in0(31 downto 12);
		when "01101" => res := zeroes(12 downto 0) & in0(31 downto 13);
		when "01110" => res := zeroes(13 downto 0) & in0(31 downto 14);
		when "01111" => res := zeroes(14 downto 0) & in0(31 downto 15);
		when "10000" => res := zeroes(15 downto 0) & in0(31 downto 16);
		when "10001" => res := zeroes(16 downto 0) & in0(31 downto 17);
		when "10010" => res := zeroes(17 downto 0) & in0(31 downto 18);
		when "10011" => res := zeroes(18 downto 0) & in0(31 downto 19);
		when "10100" => res := zeroes(19 downto 0) & in0(31 downto 20);
		when "10101" => res := zeroes(20 downto 0) & in0(31 downto 21);
		when "10110" => res := zeroes(21 downto 0) & in0(31 downto 22);
		when "10111" => res := zeroes(22 downto 0) & in0(31 downto 23);
		when "11000" => res := zeroes(23 downto 0) & in0(31 downto 24);
		when "11001" => res := zeroes(24 downto 0) & in0(31 downto 25);
		when "11010" => res := zeroes(25 downto 0) & in0(31 downto 26);
		when "11011" => res := zeroes(26 downto 0) & in0(31 downto 27);
		when "11100" => res := zeroes(27 downto 0) & in0(31 downto 28);
		when "11101" => res := zeroes(28 downto 0)& in0(31 downto 29);
		when "11110" => res := zeroes(29 downto 0) & in0(31 downto 30);
		when "11111" => res := zeroes(30 downto 0) & in0(31);	
		when others => null;
	    end case;
	    when "01011" => --sra    ändrad av matsev 010505
		if in0(31 downto 31) = "1" then  	--skifta in 1:or
		    case in1(10 downto 6) is
			when "00000" => res := in0;
			when "00001" => res := ones(0) & in0(31 downto 1);
			when "00010" => res := ones(1 downto 0) & in0(31 downto 2);
			when "00011" => res := ones(2 downto 0) & in0(31 downto 3);
			when "00100" => res := ones(3 downto 0) & in0(31 downto 4);
			when "00101" => res := ones(4 downto 0) & in0(31 downto 5);
			when "00110" => res := ones(5 downto 0) & in0(31 downto 6);
			when "00111" => res := ones(6 downto 0) & in0(31 downto 7);
			when "01000" => res := ones(7 downto 0) & in0(31 downto 8);
			when "01001" => res := ones(8 downto 0) & in0(31 downto 9);
			when "01010" => res := ones(9 downto 0) & in0(31 downto 10);
			when "01011" => res := ones(10 downto 0) & in0(31 downto 11);
			when "01100" => res := ones(11 downto 0) & in0(31 downto 12);
			when "01101" => res := ones(12 downto 0) & in0(31 downto 13);
			when "01110" => res := ones(13 downto 0) & in0(31 downto 14);
			when "01111" => res := ones(14 downto 0) & in0(31 downto 15);
			when "10000" => res := ones(15 downto 0) & in0(31 downto 16);
			when "10001" => res := ones(16 downto 0) & in0(31 downto 17);
			when "10010" => res := ones(17 downto 0) & in0(31 downto 18);
			when "10011" => res := ones(18 downto 0) & in0(31 downto 19);
			when "10100" => res := ones(19 downto 0) & in0(31 downto 20);
			when "10101" => res := ones(20 downto 0) & in0(31 downto 21);
			when "10110" => res := ones(21 downto 0) & in0(31 downto 22);
			when "10111" => res := ones(22 downto 0) & in0(31 downto 23);
			when "11000" => res := ones(23 downto 0) & in0(31 downto 24);
			when "11001" => res := ones(24 downto 0) & in0(31 downto 25);
			when "11010" => res := ones(25 downto 0) & in0(31 downto 26);
			when "11011" => res := ones(26 downto 0) & in0(31 downto 27);
			when "11100" => res := ones(27 downto 0) & in0(31 downto 28);
			when "11101" => res := ones(28 downto 0) & in0(31 downto 29);
			when "11110" => res := ones(29 downto 0) & in0(31 downto 30);
			when "11111" => res := ones(30 downto 0) & in0(31);	
			when others => null;
		    end case;
		else  			--skifta in 0:or
		    case in1(10 downto 6) is
			when "00000" => res := in0;
			when "00001" => res := zeroes(0) & in0(31 downto 1);
			when "00010" => res := zeroes(1 downto 0) & in0(31 downto 2);
			when "00011" => res := zeroes(2 downto 0) & in0(31 downto 3);
			when "00100" => res := zeroes(3 downto 0) & in0(31 downto 4);
			when "00101" => res := zeroes(4 downto 0) & in0(31 downto 5);
			when "00110" => res := zeroes(5 downto 0) & in0(31 downto 6);
			when "00111" => res := zeroes(6 downto 0) & in0(31 downto 7);
			when "01000" => res := zeroes(7 downto 0) & in0(31 downto 8);
			when "01001" => res := zeroes(8 downto 0) & in0(31 downto 9);
			when "01010" => res := zeroes(9 downto 0) & in0(31 downto 10);
			when "01011" => res := zeroes(10 downto 0) & in0(31 downto 11);
			when "01100" => res := zeroes(11 downto 0) & in0(31 downto 12);
			when "01101" => res := zeroes(12 downto 0) & in0(31 downto 13);
			when "01110" => res := zeroes(13 downto 0) & in0(31 downto 14);
			when "01111" => res := zeroes(14 downto 0) & in0(31 downto 15);
			when "10000" => res := zeroes(15 downto 0) & in0(31 downto 16);
			when "10001" => res := zeroes(16 downto 0) & in0(31 downto 17);
			when "10010" => res := zeroes(17 downto 0) & in0(31 downto 18);
			when "10011" => res := zeroes(18 downto 0) & in0(31 downto 19);
			when "10100" => res := zeroes(19 downto 0) & in0(31 downto 20);
			when "10101" => res := zeroes(20 downto 0) & in0(31 downto 21);
			when "10110" => res := zeroes(21 downto 0) & in0(31 downto 22);
			when "10111" => res := zeroes(22 downto 0) & in0(31 downto 23);
			when "11000" => res := zeroes(23 downto 0) & in0(31 downto 24);
			when "11001" => res := zeroes(24 downto 0) & in0(31 downto 25);
			when "11010" => res := zeroes(25 downto 0) & in0(31 downto 26);
			when "11011" => res := zeroes(26 downto 0) & in0(31 downto 27);
			when "11100" => res := zeroes(27 downto 0) & in0(31 downto 28);
			when "11101" => res := zeroes(28 downto 0) & in0(31 downto 29);
			when "11110" => res := zeroes(29 downto 0) & in0(31 downto 30);
			when "11111" => res := zeroes(30 downto 0) & in0(31);	
			when others => null;
		    end case;
		end if;
	    when "01100" =>  		--sllv
		if in0(31 downto 5) = 0 then
		    case in0(4 downto 0) is
			when "00000" => res := in1;
			when "00001" => res := in1(30 downto 0) & zeroes(0);
			when "00010" => res := in1(29 downto 0) & zeroes(1 downto 0);
			when "00011" => res := in1(28 downto 0) & zeroes(2 downto 0);
			when "00100" => res := in1(27 downto 0) & zeroes(3 downto 0);
			when "00101" => res := in1(26 downto 0) & zeroes(4 downto 0);
			when "00110" => res := in1(25 downto 0) & zeroes(5 downto 0);
			when "00111" => res := in1(24 downto 0) & zeroes(6 downto 0);
			when "01000" => res := in1(23 downto 0) & zeroes(7 downto 0); 
			when "01001" => res := in1(22 downto 0) & zeroes(8 downto 0);
			when "01010" => res := in1(21 downto 0) & zeroes(9 downto 0);
			when "01011" => res := in1(20 downto 0) & zeroes(10 downto 0);
			when "01100" => res := in1(19 downto 0) & zeroes(11 downto 0);
			when "01101" => res := in1(18 downto 0) & zeroes(12 downto 0);
			when "01110" => res := in1(17 downto 0) & zeroes(13 downto 0);
			when "01111" => res := in1(16 downto 0) & zeroes(14 downto 0);
			when "10000" => res := in1(15 downto 0) & zeroes(15 downto 0);
			when "10001" => res := in1(14 downto 0) & zeroes(16 downto 0);
			when "10010" => res := in1(13 downto 0) & zeroes(17 downto 0);
			when "10011" => res := in1(12 downto 0) & zeroes(18 downto 0);
			when "10100" => res := in1(11 downto 0) & zeroes(19 downto 0);
			when "10101" => res := in1(10 downto 0) & zeroes(20 downto 0);
			when "10110" => res := in1(9 downto 0) & zeroes(21 downto 0);
			when "10111" => res := in1(8 downto 0) & zeroes(22 downto 0); 
			when "11000" => res := in1(7 downto 0) & zeroes(23 downto 0);
			when "11001" => res := in1(6 downto 0) & zeroes(24 downto 0);
			when "11010" => res := in1(5 downto 0) & zeroes(25 downto 0);
			when "11011" => res := in1(4 downto 0) & zeroes(26 downto 0);
			when "11100" => res := in1(3 downto 0) & zeroes(27 downto 0);
			when "11101" => res := in1(2 downto 0) & zeroes(28 downto 0);
			when "11110" => res := in1(1 downto 0) & zeroes(29 downto 0);
			when "11111" => res := in1(0) & zeroes(30 downto 0);
			when others => null;
		    end case;
		else
		    res := zeroes;
		end if;
	    when "01110" =>  		--srlv
		if in0(31 downto 5) = 0 then
		    case in0(4 downto 0) is  
			when "00000" => res := in1;
			when "00001" => res := zeroes(0) & in1(31 downto 1);
			when "00010" => res := zeroes(1 downto 0) & in1(31 downto 2);
			when "00011" => res := zeroes(2 downto 0) & in1(31 downto 3);
			when "00100" => res := zeroes(3 downto 0) & in1(31 downto 4);
			when "00101" => res := zeroes(4 downto 0) & in1(31 downto 5);
			when "00110" => res := zeroes(5 downto 0) & in1(31 downto 6);
			when "00111" => res := zeroes(6 downto 0) & in1(31 downto 7);
			when "01000" => res := zeroes(7 downto 0) & in1(31 downto 8);
			when "01001" => res := zeroes(8 downto 0) & in1(31 downto 9);
			when "01010" => res := zeroes(9 downto 0) & in1(31 downto 10);
			when "01011" => res := zeroes(10 downto 0) & in1(31 downto 11);
			when "01100" => res := zeroes(11 downto 0) & in1(31 downto 12);
			when "01101" => res := zeroes(12 downto 0) & in1(31 downto 13);
			when "01110" => res := zeroes(13 downto 0) & in1(31 downto 14);
			when "01111" => res := zeroes(14 downto 0) & in1(31 downto 15);
			when "10000" => res := zeroes(15 downto 0) & in1(31 downto 16);
			when "10001" => res := zeroes(16 downto 0) & in1(31 downto 17);
			when "10010" => res := zeroes(17 downto 0) & in1(31 downto 18);
			when "10011" => res := zeroes(18 downto 0) & in1(31 downto 19);
			when "10100" => res := zeroes(19 downto 0) & in1(31 downto 20);
			when "10101" => res := zeroes(20 downto 0) & in1(31 downto 21);
			when "10110" => res := zeroes(21 downto 0) & in1(31 downto 22);
			when "10111" => res := zeroes(22 downto 0) & in1(31 downto 23);
			when "11000" => res := zeroes(23 downto 0) & in1(31 downto 24);
			when "11001" => res := zeroes(24 downto 0) & in1(31 downto 25);
			when "11010" => res := zeroes(25 downto 0) & in1(31 downto 26);
			when "11011" => res := zeroes(26 downto 0) & in1(31 downto 27);
			when "11100" => res := zeroes(27 downto 0) & in1(31 downto 28);
			when "11101" => res := zeroes(28 downto 0)& in1(31 downto 29);
			when "11110" => res := zeroes(29 downto 0) & in1(31 downto 30);
			when "11111" => res := zeroes(30 downto 0) & in1(31);	
			when others => null;
		    end case;
		else
		    res := zeroes;
		end if;
	    when "00111" =>  		--srav ändrad 010227 av mch bytt mot lui.
                                        --ändrad av matsev 010505
		if in1(31 downto 31) = "1" then  	--skifta in 1:or
		    if in0(30 downto 5) = 0 then
			case in0(4 downto 0) is  -- ändrad 010227 av mch från(10downto6)
			    when "00000" => res := in1;
			    when "00001" => res := ones(0) & in1(31 downto 1);
			    when "00010" => res := ones(1 downto 0) & in1(31 downto 2);
			    when "00011" => res := ones(2 downto 0) & in1(31 downto 3);
			    when "00100" => res := ones(3 downto 0) & in1(31 downto 4);
			    when "00101" => res := ones(4 downto 0) & in1(31 downto 5);
			    when "00110" => res := ones(5 downto 0) & in1(31 downto 6);
			    when "00111" => res := ones(6 downto 0) & in1(31 downto 7);
			    when "01000" => res := ones(7 downto 0) & in1(31 downto 8);
			    when "01001" => res := ones(8 downto 0) & in1(31 downto 9);
			    when "01010" => res := ones(9 downto 0) & in1(31 downto 10);
			    when "01011" => res := ones(10 downto 0) & in1(31 downto 11);
			    when "01100" => res := ones(11 downto 0) & in1(31 downto 12);
			    when "01101" => res := ones(12 downto 0) & in1(31 downto 13);
			    when "01110" => res := ones(13 downto 0) & in1(31 downto 14);
			    when "01111" => res := ones(14 downto 0) & in1(31 downto 15);
			    when "10000" => res := ones(15 downto 0) & in1(31 downto 16);
			    when "10001" => res := ones(16 downto 0) & in1(31 downto 17);
			    when "10010" => res := ones(17 downto 0) & in1(31 downto 18);
			    when "10011" => res := ones(18 downto 0) & in1(31 downto 19);
			    when "10100" => res := ones(19 downto 0) & in1(31 downto 20);
			    when "10101" => res := ones(20 downto 0) & in1(31 downto 21);
			    when "10110" => res := ones(21 downto 0) & in1(31 downto 22);
			    when "10111" => res := ones(22 downto 0) & in1(31 downto 23);
			    when "11000" => res := ones(23 downto 0) & in1(31 downto 24);
			    when "11001" => res := ones(24 downto 0) & in1(31 downto 25);
			    when "11010" => res := ones(25 downto 0) & in1(31 downto 26);
			    when "11011" => res := ones(26 downto 0) & in1(31 downto 27);
			    when "11100" => res := ones(27 downto 0) & in1(31 downto 28);
			    when "11101" => res := ones(28 downto 0) & in1(31 downto 29);
			    when "11110" => res := ones(29 downto 0) & in1(31 downto 30);
			    when "11111" => res := ones(30 downto 0) & in1(31);	
			    when others => null;
			end case;	
		    else
			res := ones;
		    end if;
		else		        -- skifta in 0:or
		    if in0(30 downto 5) = 0 then
			case in0(4 downto 0) is  
			    when "00000" => res := in1;
			    when "00001" => res := zeroes(0) & in1(31 downto 1);
			    when "00010" => res := zeroes(1 downto 0) & in1(31 downto 2);
			    when "00011" => res := zeroes(2 downto 0) & in1(31 downto 3);
			    when "00100" => res := zeroes(3 downto 0) & in1(31 downto 4);
			    when "00101" => res := zeroes(4 downto 0) & in1(31 downto 5);
			    when "00110" => res := zeroes(5 downto 0) & in1(31 downto 6);
			    when "00111" => res := zeroes(6 downto 0) & in1(31 downto 7);
			    when "01000" => res := zeroes(7 downto 0) & in1(31 downto 8);
			    when "01001" => res := zeroes(8 downto 0) & in1(31 downto 9);
			    when "01010" => res := zeroes(9 downto 0) & in1(31 downto 10);
			    when "01011" => res := zeroes(10 downto 0) & in1(31 downto 11);
			    when "01100" => res := zeroes(11 downto 0) & in1(31 downto 12);
			    when "01101" => res := zeroes(12 downto 0) & in1(31 downto 13);
			    when "01110" => res := zeroes(13 downto 0) & in1(31 downto 14);
			    when "01111" => res := zeroes(14 downto 0) & in1(31 downto 15);
			    when "10000" => res := zeroes(15 downto 0) & in1(31 downto 16);
			    when "10001" => res := zeroes(16 downto 0) & in1(31 downto 17);
			    when "10010" => res := zeroes(17 downto 0) & in1(31 downto 18);
			    when "10011" => res := zeroes(18 downto 0) & in1(31 downto 19);
			    when "10100" => res := zeroes(19 downto 0) & in1(31 downto 20);
			    when "10101" => res := zeroes(20 downto 0) & in1(31 downto 21);
			    when "10110" => res := zeroes(21 downto 0) & in1(31 downto 22);
			    when "10111" => res := zeroes(22 downto 0) & in1(31 downto 23);
			    when "11000" => res := zeroes(23 downto 0) & in1(31 downto 24);
			    when "11001" => res := zeroes(24 downto 0) & in1(31 downto 25);
			    when "11010" => res := zeroes(25 downto 0) & in1(31 downto 26);
			    when "11011" => res := zeroes(26 downto 0) & in1(31 downto 27);
			    when "11100" => res := zeroes(27 downto 0) & in1(31 downto 28);
			    when "11101" => res := zeroes(28 downto 0) & in1(31 downto 29);
			    when "11110" => res := zeroes(29 downto 0) & in1(31 downto 30);
			    when "11111" => res := zeroes(30 downto 0) & in1(31);	
			    when others => null;
			end case;	
		    else
			res := ones;
		    end if;
		end if;
	    when "10000" => --add, addi, lw, sw
		res := add(31 downto 0);
		setoverflow <= add(32 downto 32);
		if (in0(31)='0' and in1(31)='0' and add(31)='1') or (in0(31)='1' and in1(31)='1' and add(31)='0') then
		    setaritmetico <= "1";
		end if;	
	    when "10001" => --addu, addiu
		res := add(31 downto 0);
		overflowout <= sub(32 downto 32);
		setoverflow <= add(32 downto 32);
     	    when "10010" => --sub, beq, bne, bge, bgt
		res := sub(31 downto 0);
		setoverflow <= sub(32 downto 32);
		overflowout <= sub(32 downto 32);
		if (in0(31)='0' and in1(31)='1' and sub(31)='1') or (in0(31)='1' and in1(31)='0' and sub(31)='0') then
		    setaritmetico <= "1";
		end if;
	    when "10011" =>  --subu
		res := sub(31 downto 0);	--overflow???
		setoverflow <= sub(32 downto 32);
	    when "10100" => res := in0 and in1;  --and, andi
	    when "10101" => res := in0 or in1;  --or, ori
	    when "10110" => res := in0 xor in1;  --xor, xori	      
	    when "10111" => res := in0 nor in1;  --nor
	    when "11100" => res := zeroes(28 downto 0) & overflow & aritmetico & delayedzero;	--mfc0 visa alu:ns statusregister
	    when "11101" =>  		--mfc1 visa grafikdata
		case in1(1 downto 0) is
		    when "00" => res := grafix;  --visa all data
		    when "01" => res := zeroes(19 downto 0) & grafix(31 downto 20);  --visa framecnt
		    when "10" => res := zeroes(20 downto 0) & grafix(19 downto 9);  --visa horcnt
		    when "11" => res := zeroes(22 downto 0) & grafix(8 downto 0);  --visa pixelcnt
		    when others => null;
		end case;
	    when "11110" => res := zeroes(23 downto 0) & joystick(7 downto 0);  --mfc2 joystickdata
	    when "11111" => res := modplayer;
	    when "11010" =>  --slt, slti overflow???
		if (sub(31) = '1') then
		    res := (zeroes(31 downto 1) & "1");  	--Kontrollera ordningen pa in1 resp in0!!!
		else
		    res := zeroes;
		end if;
	    when "11011" => --sltu, sltiu overflow???
		if (sub(32) = '1') then
		    res := (zeroes(31 downto 1) & "1");
		else
		    res := zeroes;
		end if;
      	    when others => null; --Default
	end case;
	if res = 0 then
	    zero <= "0";
	    setzero <= "0";
	end if;
	out0 <= res;
    end process;

    process(clk,reset)
    begin
	if reset="0" then
	    overflow <= (others=>'0');
	    aritmetico <= (others=>'0');
	    delayedzero <= (others=>'0');
	elsif rising_edge(clk) then
	     overflow <= setoverflow;
	     aritmetico <= setaritmetico;
	     delayedzero <= setzero;
	end if;
    end process;

end alu_behavioral;






