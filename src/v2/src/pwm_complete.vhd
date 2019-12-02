-------------------------------------------------------------------------------
-- Title      : PWM complete
-- Project    : PWM IP Cores
-------------------------------------------------------------------------------
-- File       : pwm_complete.vhd
-- Author     : Cristian  <cristian@c7technology.com>
-- Company    : C7T
-- Created    : 2018-06-12
-- Last update: 2018-10-11
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: generation of the PWM signal using Rd/Wr registers that
-- will be Wr/Rd through the AXI bus.
-- 
-- The following register are defined for this PWM IP:
--
-- ----------------       Register 0: Control Register   ----------------------
-- bit31 | ... |   bit 4   |   bit 3   |   bit2   |   bit 1   |   bit 0   |
--                clear        Enable    invert PWM   enable    sw reset_n
--               interrupt    interrupt   output      disable
--
-- ----------------       Register 1: Status Register    ----------------------
-- bit31 | ... | ... ... ... ... ... ... ... ...   |  bit 1   |   bit 0   |
--                                                  interrupt   PWM output
--                                                    request    value
-- 
-- ----------------------       Register 2     --------------------------------
-- Writable register: ARM will write into this register the PWM (duty cycle) value
--
-- ----------------------       Register 3     --------------------------------
-- Readable register: hold the current version of the PWM IP module
--
-- ----------------------       Register 4     --------------------------------
-- Readable register: copy of Register 2, that can be read by the ARM
--
--  ----------------------       Outputs     --------------------------------
-- pwm: which is the PWM value, '0' or '1' 
-- int_pwm: which generate an int request (goes to '1') on the falling edge
-- of the pwm ouptut. 
-------------------------------------------------------------------------------
-- 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2018-06-12  1.0      cristian	Created
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- library declarations
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-------------------------------------------------------------------------------
-- entity declaration
-------------------------------------------------------------------------------
entity pwm_complete is
  
  generic (
    dc_bits : integer := 32);            -- number of bits for the duty cycle 

  port (
    -- clock & reset signals
    S_AXI_ACLK         : in  std_logic;  -- AXI clock
    S_AXI_ARESETN      : in  std_logic;  -- AXI async reset, active low

    -- registers
    reg0_control       : in  std_logic_vector(31 downto 0);
    reg1_status        : out std_logic_vector(31 downto 0);
    reg2_pwm_dc_value  : in  std_logic_vector(31 downto 0);
    reg3_ip_version    : out std_logic_vector(31 downto 0);
    reg4_pwm_dc_value  : out std_logic_vector(31 downto 0);
    
    -- PWM output 
    pwm                : out std_logic;          -- pwn output;

    -- Int request output
    pwm_int_req        : out std_logic
    );        
end entity pwm_complete;

-------------------------------------------------------------------------------
-- architecture
-------------------------------------------------------------------------------
architecture beh of pwm_complete is

  -- PWM IP version constant declaration
  constant pwm_version_ctt : std_logic_vector(31 downto 0) := X"00010001";  -- V 1.1

  -- alias declaration for the different bits of the control register
  alias soft_reset_bit_n: std_logic is reg0_control(0);  -- sw reset initialized by
                                                              -- PS7, active low
  alias enable_bit      : std_logic is reg0_control(1);  -- enable the whole PWM module
  alias pwm_invert_bit  : std_logic is reg0_control(2);  -- invert the PWM output when '1'
  alias enable_int_bit  : std_logic is reg0_control(3);  -- enable int when '1' 
  alias clear_int_bit   : std_logic is reg0_control(4);  -- clear int request
  alias duty_cycle_reg  : std_logic_vector(31 downto 0) is reg2_pwm_dc_value(31 downto 0);  -- initial duty cycle value

  -- internal signal declarations
  signal reset_n        : std_logic;                      -- global reset (hw and sw)
  signal pwm_i          : std_logic;                      -- internal pwm generation
  signal pwm_dly        : std_logic;                      -- one clock delayed version of pwm_i
  signal pwm_out_i      : std_logic;                      -- internal pwm ouptut
  signal int_req_bit_i  : std_logic;                      -- internal int request signal
 
begin  -- architecture beh

  -- assign version number to version register
  reg3_ip_version <= pwm_version_ctt;

  -- update status reg to be read by the ARM 
  reg1_status  <= ((1) => int_req_bit_i,  -- int request bit
                   (0) => pwm_out_i,      -- current pwm output value
                   others => '0');
  
  -- assign current duty cycle to read register
  reg4_pwm_dc_value <= duty_cycle_reg;      -- current value of duty cycle to be read 

  -- reset = hw_reset or sf_reset
  reset_n <=  S_AXI_ARESETN and soft_reset_bit_n;  

  ---&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&---
  -----------------------------------------------------------------------------
  -- duty cycle process
  -- count clock cycles until reach the value in 'alias' duty_cycle (reg2)
  -----------------------------------------------------------------------------
  pwm_pr : process (S_AXI_ACLK, reset_n) is 
   variable counter : unsigned(dc_bits-1 downto 0);      -- count clocks tick
  begin  --
    if (reset_n = '0') then
      counter        := (others => '0');
      pwm_i          <= '0';
     -- duty_cycle_reg <= 0X"0000FF00"; 
    elsif (rising_edge(S_AXI_ACLK)) then  
      if (enable_bit = '1')  then
        counter := counter + 1;
        if (counter < unsigned(duty_cycle_reg)) then
          pwm_i <= '1';
        else
          pwm_i <= '0';
        end if;
      end if; 
    end if;
  end process pwm_pr;

  -- invert PWM output when required
  pwm_out_i     <= not pwm_i when (pwm_invert_bit = '1') else pwm_i;
  pwm           <= pwm_out_i;             -- entity output
  -- pwm_value_bit <= pwm_out_i;             -- status register bit 0
  

  ---&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&---
  -------------------------------------------------------------------------------
  -- the following two process are related to interrupt generation
  -- negative edge detection for pwm_i to generate an interrupt request
  -- the interrupt request is cleared by the software by writing '1' to the
  -- int clear bit in the control register
  -------------------------------------------------------------------------------
  int_pwm_dly_pr: process (S_AXI_ACLK, reset_n)is 
  begin 
    if reset_n='0' then
      pwm_dly <= '0';
    elsif rising_edge(S_AXI_ACLK) then
      if (enable_int_bit='1') then 
        pwm_dly <= pwm_i;
      end if;
    end if;
  end process int_pwm_dly_pr;

  -----------------------------------------------------------------------------
  -- int_request_bit goes to '1' until clear_int_bit is '1'
  -- negative edge detection for pwm_i to generate an interrupt request
  -- the interrupt request is cleared by the software by writing '1' to the
  -- int clear bit in the control register
  -----------------------------------------------------------------------------
  int_req_pr: process (S_AXI_ACLK, reset_n) is
  begin  
    if (reset_n = '0') then              
      int_req_bit_i <= '0';
    elsif (rising_edge(S_AXI_ACLK)) then 
      if (clear_int_bit='1') then
        int_req_bit_i <= '0';
      elsif ((pwm_i='0') and (pwm_dly='1')) then  -- neg edge detection
        int_req_bit_i <= '1';
      end if;
    end if;
  end process int_req_pr;
  -------------------------------------------------------------------------------

  pwm_int_req <= int_req_bit_i;         -- output from this module
  --int_req_bit <= int_req_bit_i;         -- status register bit 1

  -----------------------------------------------------------------------------
  
end architecture beh;

-------------------------------------------------------------------------------
-- EOF 
-------------------------------------------------------------------------------
