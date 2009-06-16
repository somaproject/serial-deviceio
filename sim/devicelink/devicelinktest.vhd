
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

library UNISIM;
use UNISIM.VComponents.all;

entity devicelinktest is

end devicelinktest;

architecture Behavioral of devicelinktest is


  component devicelink
    port (
      TXCLKIN    : in  std_logic;       -- We still assume this is 50 MHz
      TXLOCKED   : in  std_logic;
      TXDIN      : in  std_logic_vector(9 downto 0);
      TXDOUT     : out std_logic_vector(7 downto 0);
      TXKOUT     : out std_logic;
      CLK        : out std_logic;
      CLK2X      : out std_logic;
      RESET      : out std_logic;
      RXDIN      : in  std_logic_vector(7 downto 0);  -- input clock tick
      RXKIN      : in  std_logic;
      RXIO_P     : out std_logic;
      RXIO_N     : out std_logic;
      DEBUGSTATE : out std_logic_vector(3 downto 0);
      DECODEERR  : out std_logic
      );

  end component;

  component encode8b10b
    port (
      din  : in  std_logic_vector(7 downto 0);
      kin  : in  std_logic;
      clk  : in  std_logic;
      dout : out std_logic_vector(9 downto 0));
  end component;


  component decode8b10b
    port (
      clk      : in  std_logic;
      din      : in  std_logic_vector(9 downto 0);
      dout     : out std_logic_vector(7 downto 0);
      kout     : out std_logic;
      code_err : out std_logic;
      disp_err : out std_logic);
  end component;


  signal fastclk : integer := 0;

  signal TXCLKIN      : std_logic                    := '0';  -- We still assume this is 50 MHz
  signal TXLOCKED     : std_logic                    := '1';
  signal TXDIN        : std_logic_vector(9 downto 0) := (others => '0');
  signal TXDOUT       : std_logic_vector(7 downto 0) := (others => '0');
  signal TXKOUT       : std_logic                    := '0';
  signal CLK          : std_logic                    := '0';
  signal CLK2X        : std_logic                    := '0';
  signal DEVICE_RESET : std_logic                    := '0';
  signal RXDIN        : std_logic_vector(7 downto 0) := (others => '0');  -- input clock tick
  signal RXKIN        : std_logic                    := '0';
  signal RXIO_P       : std_logic                    := '0';
  signal RXIO_N       : std_logic                    := '0';
  signal DEBUGSTATE   : std_logic_vector(3 downto 0) := (others => '0');
  signal DECODEERR    : std_logic                    := '0';

  signal to_device_din : std_logic_vector(7 downto 0) := (others => '0');
  signal to_device_kin : std_logic                    := '0';

  signal from_device_word : std_logic_vector(9 downto 0) := (others => '0');

  signal from_device_dout : std_logic_vector(7 downto 0) := (others => '0');
  signal from_device_kout : std_logic                    := '0';

  signal from_device_code_err, from_device_disp_err : std_logic := '0';

  signal link_up : std_logic := '0';
  
begin  -- Behavioral

  devicelink_uut : devicelink
    port map (
      TXCLKIN    => TXCLKIN,
      TXLOCKED   => TXLOCKED,
      TXDIN      => TXDIN,
      TXDOUT     => TXDOUT,
      TXKOUT     => TXKOUT,
      CLK        => CLK,
      CLK2X      => CLK2X,
      RESET      => DEVICE_RESET,
      RXDIN      => RXDIN,
      RXKIN      => RXKIN,
      RXIO_P     => RXIO_P,
      RXIO_N     => RXIO_N,
      DEBUGSTATE => DEBUGSTATE,
      DECODEERR  => DECODEERR);

  to_device_encode : encode8b10b
    port map (
      din  => to_device_din,
      kin  => to_device_kin,
      clk  => TXCLKIN,
      dout => TXDIN);

  from_device_decode : decode8b10b
    port map (
      clk      => TXCLKIN,
      din      => from_device_word,
      kout     => from_device_kout,
      dout     => from_device_dout,
      code_err => from_device_code_err,
      disp_err => from_device_disp_err);

  fastclockproc : process
  begin  -- process fastclockproc
    while true loop
      if fastclk = 9 then
        fastclk <= 0;
      else
        fastclk <= fastclk + 1;
      end if;
      wait for 2 ns;
    end loop;
  end process fastclockproc;

  process (fastclk)
  begin
    if fastclk'event then
      if fastclk = 0 then
        TXCLKIN <= '0';
      elsif fastclk = 5 then
        TXCLKIN <= '1';
      end if;
    end if;
  end process;


  TXLOCKED <= '0' after 1 us;

  --  now we try and capture
  mainrecover : process
    variable corelocked   : boolean                      := false;
    variable capturedword : std_logic_vector(9 downto 0) := (others => '0');

  begin
    corelocked := false;
    while not corelocked loop
      wait on fastclk;
      capturedword := RXIO_P & capturedword(9 downto 1) ;
      if capturedword = "1101000011" or capturedword = "0010111100" then
        corelocked := true;
      end if;
    end loop;

    while true loop
      for i in 1 to 10 loop
        wait on fastclk;
        capturedword :=  RXIO_P & capturedword(9 downto 1); 
      end loop;  -- i
      from_device_word <= capturedword;
    end loop;

    wait;

  end process;

  maincontroL : process
  begin
    wait until from_device_code_err = '0' and
      from_device_disp_err = '0';
    link_up <= '1';

    -- now send the valid ack word
    wait for 10 us;                     -- delay
    wait until rising_edge(TXCLKIN);
    to_device_kin <= '1';
    to_device_din <= X"FE";
    wait until rising_edge(TXCLKIN);
    to_device_kin <= '0';
    wait until DEVICE_RESET = '0';

    wait;
  end process maincontrol;

  device_send_data : process
  begin
    wait until rising_edge(TXCLKIN) and DEVICE_RESET = '0';
    while true loop
      for i in 0 to 255 loop
        RXDIN <= std_logic_vector(TO_UNSIGNED(i, 8));
        wait until rising_edge(TXCLKIN);
      end loop;  -- i
    end loop;
  end process device_send_data;

  device_verify_data: process
    variable lastword : std_logic_vector(7 downto 0) := (others => '0');
    variable goodcnt : integer := 0;
    begin
      while true loop
        wait until rising_edge(TXCLKIN);

        if DEVICE_RESET='0' then
          if from_device_dout = lastword + 1 then
            goodcnt := goodcnt + 1;
          else
            goodcnt := 0;
          end if;
          lastword := from_device_dout; 
        end if;

        if goodcnt = 255 then
          report "End of Simulation" severity failure;
        end if;
        
      end loop;
    end process; 
end Behavioral;
