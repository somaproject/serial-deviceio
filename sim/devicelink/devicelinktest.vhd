
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

  component dlencode8b10b
    port (
      din        : in  std_logic_vector(7 downto 0);
      kin        : in  std_logic;
      clk        : in  std_logic;
      dout       : out std_logic_vector(9 downto 0);
      ce         : in  std_logic;
      force_code : in  std_logic;
      force_disp : in  std_logic;
      disp_in    : in  std_logic);
  end component;


  component dldecode8b10b
    port (
      clk   : in  std_logic;
      din   : in  std_logic_vector(9 downto 0);
      dout  : out std_logic_vector(7 downto 0);
      kout  : out std_logic;
      ce    : in  std_logic;
      sinit : in  std_logic;

      code_err : out std_logic;
      disp_err : out std_logic);
  end component;


  signal fastclk     : integer := 0;
  signal halffastclk : integer := 0;

  signal TXCLKIN      : std_logic                    := '0';  -- We still assume this is 50 MHz
  signal RXCLK        : std_logic                    := '0';
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
  signal from_device_wordl : std_logic_vector(9 downto 0) := (others => '0');

  signal from_device_dout : std_logic_vector(7 downto 0) := (others => '0');
  signal from_device_kout : std_logic                    := '0';

  signal from_device_code_err, from_device_disp_err : std_logic := '0';

  signal link_up : std_logic := '0';

  signal encodece : std_logic := '0';
  signal decodece : std_logic := '0';
  signal decodece_en, decodece_alt : std_logic := '0';
  
  signal linklocked : boolean := false;
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

  to_device_encode : dlencode8b10b
    port map (
      din        => to_device_din,
      kin        => to_device_kin,
      clk        => TXCLKIN,
      ce         => encodece,
      dout       => TXDIN,
      force_code => '0',
      force_disp => '0',
      disp_in    => '0');

  from_device_decode : dldecode8b10b
    port map (
      clk      => RXCLK,
      din      => from_device_wordl,
      kout     => from_device_kout,
      dout     => from_device_dout,
      ce       => decodece,
      sinit    => '0',
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

      if fastclk = 0 then
        RXCLK <= not RXCLK;
      end if;

      if fastclk mod 2 = 1 then
        if halffastclk = 4 then
          halffastclk <= 0;
        else
          halffastclk <= halffastclk + 1;
        end if;
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
    linklocked <= false; 
    while not corelocked loop
      wait on halffastclk;
      capturedword := RXIO_P & capturedword(9 downto 1);
      if capturedword = "1011110000" then
        corelocked := true;
      end if;
    end loop;
    while true loop
      for i in 1 to 10 loop
        wait on halffastclk;
        capturedword := RXIO_P & capturedword(9 downto 1);
      end loop;  -- i
      from_device_word <= capturedword;
      linklocked <= true; 
      
    end loop;

    wait;

  end process;

  process(txclkin)
    begin
      if rising_edge(txclkin) then
        from_device_wordl <= from_device_word;
        decodece_alt <= not decodece_alt;
      end if;
    end process;
    decodece <= decodece_en and decodece_alt;
    
    
  handshake: process
  begin  -- process handshake
    wait until rising_edge(TXCLKIN) and linklocked ;
    -- now send handshake
    wait until rising_edge(TXCLKIN);
    wait for 10 us;
    wait until rising_edge(TXCLKIN);
    to_device_kin <= '1';
    to_device_din <= X"3C";
    encodece <= '1'; 
    wait until rising_edge(TXCLKIN); 
    to_device_kin <= '0';

    -- now wait for reciprocity
    wait until rising_edge(TXCLKIN) and from_device_word = "0110000011" ;
    decodece_en <= '1';
    -- now we're basically up
    wait until rising_edge(TXCLKIN); 
    to_device_kin <= '1';
    to_device_din <= X"FE";
    wait until rising_edge(TXCLKIN); 
    to_device_kin <= '0';
    
    link_up <= '1'; 
    wait; 
    
  end process handshake;

  

  device_send_data : process
  begin
    wait until rising_edge(TXCLKIN) and DEVICE_RESET = '0';
    while true loop
      for i in 0 to 255 loop
        RXDIN <= std_logic_vector(TO_UNSIGNED(i, 8));
        wait until rising_edge(TXCLKIN);
        wait until rising_edge(TXCLKIN);
      end loop;  -- i
    end loop;
  end process device_send_data;

  device_verify_data : process
    variable lastword : std_logic_vector(7 downto 0) := (others => '0');
    variable goodcnt  : integer                      := 0;
  begin
    while true loop
      wait until rising_edge(RXCLK) and link_up = '1' ;

      if DEVICE_RESET = '0' then
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
