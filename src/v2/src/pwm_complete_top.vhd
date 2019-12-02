-------------------------------------------------------------------------------
-- Title      : Top PWM Complete
-- Project    : 
-------------------------------------------------------------------------------
-- File       : pwm_complete_top.vhd
-- Author     : Cristian Sisterna  <cristian@cactus>
-- Company    : C7T
-- Created    : 2018-10-08
-- Last update: 2018-10-08
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Instantiation of the pwm_complete.vhd component in a higher 
-- hierarchy component (top). Just to have clean .vhd component. this component
-- will be connected to the AXI bus by making it an IP Core with the Vivado
-- IP tools
-------------------------------------------------------------------------------
-- Copyright (c) 2018 C7T
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2018-10-08  1.0      cristian	Created
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- 
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-------------------------------------------------------------------------------
-- entity declaration
-------------------------------------------------------------------------------
entity pwm_complete_top is
  port (
     -- clock & reset signals
    S_AXI_ACLK        : in  std_logic;  -- AXI clock
    S_AXI_ARESETN     : in  std_logic;  -- AXI async reset, active low

    -- registers
    reg0_control      : in  std_logic_vector(31 downto 0);
    reg1_status       : out std_logic_vector(31 downto 0);
    reg2_pwm_dc_value : in  std_logic_vector(31 downto 0);
    reg3_ip_version   : out std_logic_vector(31 downto 0);
    reg4_pwm_dc_value : out std_logic_vector(31 downto 0);
	 
    -- PWM output 
    pwm                : out std_logic;          -- pwn output
	 
	 -- Int request output
	 pwm_int_req		  : out std_logic
	 
	 
    );        
end entity pwm_complete_top;

-------------------------------------------------------------------------------
-- architecture
-------------------------------------------------------------------------------
architecture structural of pwm_complete_top is

begin  

U1: entity work.pwm_complete
  port map (
    S_AXI_ACLK        => S_AXI_ACLK,
    S_AXI_ARESETN     => S_AXI_ARESETN,
    reg0_control      => reg0_control,
    reg1_status       => reg1_status,
    reg2_pwm_dc_value => reg2_pwm_dc_value,
    reg3_ip_version   => reg3_ip_version,
    reg4_pwm_dc_value => reg4_pwm_dc_value,
    pwm               => pwm,
	 pwm_int_req       => pwm_int_req);

end architecture structural;

-------------------------------------------------------------------------------
-- EOF
-------------------------------------------------------------------------------
