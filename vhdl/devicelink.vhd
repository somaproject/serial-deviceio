
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;


library UNISIM;
use UNISIM.VComponents.all;

entity devicelink is
  port (
    TXCLKIN    : in  std_logic;         -- We still assume this is 50 MHz
    TXLOCKED   : in  std_logic;
    TXDIN      : in  std_logic_vector(9 downto 0);
    TXDOUT     : out std_logic_vector(7 downto 0);
    TXKOUT     : out std_logic;
    CLK        : out std_logic;
    CLK2X      : out std_logic;
    RESET      : out std_logic;
    RXDIN      : in  std_logic_vector(7 downto 0);
    RXKIN      : in  std_logic;
    RXIO_P     : out std_logic;
    RXIO_N     : out std_logic;
    LINKLOCK   : out std_logic;
    DEBUGSTATE : out std_logic_vector(3 downto 0);
    DEBUGOUT   : out std_logic_vector(31 downto 0) := (others => '0');
    DECODEERR  : out std_logic
    );

end devicelink;

architecture Behavioral of devicelink is

  signal nottxlocked                   : std_logic := '0';
  signal dcmlocked                     : std_logic := '0';
  signal txclkint, txclk               : std_logic := '0';
  signal rxhbitclk, rxhbitclkint       : std_logic := '0';
  signal rxhbitclk180, rxhbitclk180int : std_logic := '0';
  signal rst                           : std_logic := '0';


  signal txdinl, txdinll : std_logic_vector(9 downto 0) := (others => '0');
  signal ltxdout         : std_logic_vector(7 downto 0) := (others => '0');

  signal cerr    : std_logic := '0';
  signal derr    : std_logic := '0';
  signal ltxkout : std_logic := '0';

  signal encrst : std_logic := '1';

  signal rxdinl : std_logic_vector(7 downto 0) := (others => '0');
  signal rxkinl : std_logic                    := '0';
  signal dsel   : std_logic                    := '0';

  signal DIN : std_logic_vector(7 downto 0) := (others => '0');
  signal kin : std_logic                    := '0';

  signal ol, oll : std_logic_vector(9 downto 0) := (others => '0');

  signal forceerr     : std_logic                     := '0';
  signal txcodeerr    : std_logic                     := '0';
  signal txcodeerrreg : std_logic_vector(63 downto 0) := (others => '1');
  signal rxcontrol    : std_logic                     := '0';

  signal rxsenden : std_logic := '0';

  signal sout : std_logic_vector(9 downto 0) := (others => '0');

  signal rxio : std_logic := '0';

  signal ldebugstate : std_logic_vector(3 downto 0) := (others => '0');

  signal encodece : std_logic := '0';
  signal decodece : std_logic := '0';
  
  type   states is (none, sendsync, encst1, encst2, waitup, lock, unlocked);
  signal cs, ns : states := none;

  component dlencode8b10b
    port (
      din        : in  std_logic_vector(7 downto 0);
      kin        : in  std_logic;
      clk        : in  std_logic;
      ce         : in  std_logic;
      dout       : out std_logic_vector(9 downto 0);
      force_disp : in  std_logic;
      disp_in    : in  std_logic);
  end component;


  component dldecode8b10b
    port (
      clk   : in  std_logic;
      din   : in  std_logic_vector(9 downto 0);
      dout  : out std_logic_vector(7 downto 0);
      kout  : out std_logic;
      sinit : in  std_logic;
      ce : in std_logic; 

      code_err : out std_logic;
      disp_err : out std_logic);
  end component;


begin  -- Behavioral

  encoder : dlencode8b10b
    port map (
      DIN        => din,
      KIN        => kin,
      DOUT       => ol,
      CE         => encodece,
      CLK        => txclk,
      force_disp => encrst,
      disp_in    => '1');

  decoder : dldecode8b10b
    port map (
      CLK      => txclk,
      DIN      => txdinll,
      DOUT     => ltxdout,
      KOUT     => ltxkout,
      sinit    => encrst,
      ce => decodece, 
      CODE_ERR => cerr,
      DISP_ERR => derr);

  nottxlocked <= TXLOCKED;
  rst         <= not dcmlocked;

  RESET <= rst;
  txclkdcm : dcm generic map (
    CLKFX_DIVIDE       => 2,
    CLKFX_MULTIPLY     => 5,
    DLL_FREQUENCY_MODE => "LOW",
    DFS_FREQUENCY_MODE => "LOW")
    port map (
      CLKIN    => TXCLKIN,
      CLKFB    => txclk,
      RST      => nottxlocked,
      PSEN     => '0',
      CLK0     => txclkint,
      CLK2x    => CLK2X,
      CLKFX    => rxhbitclkint,
      CLKFX180 => rxhbitclk180int,
      LOCKED   => dcmlocked);

  txclk_bufg : BUFG port map (
    O => txclk,
    I => txclkint);

  CLK <= txclk;

  rxhbitclk_bufg : BUFG port map (
    O => rxhbitclk,
    I => rxhbitclkint);

  rxhbitclk180_bufg : BUFG port map (
    O => rxhbitclk180,
    I => rxhbitclk180int);


  DIN <= rxdinl when dsel = '0' else X"3C";
  KIN <= rxkinl when dsel = '0' else '1';


  txcodeerr <= cerr or derr;

  DECODEERR  <= txcodeerr;
  DEBUGSTATE <= ldebugstate;

  FDDRRSE_inst : FDDRRSE
    port map (
      Q  => rxio,                       -- Data output 
      C0 => RXHBITCLK,                  -- 0 degree clock input
      C1 => RXHBITCLK180,               -- 180 degree clock input
      CE => '1',                        -- Clock enable input
      D0 => sout(1),                    -- Posedge data input
      D1 => sout(0),                    -- Negedge data input
      R  => '0',                        -- Synchronous reset input
      S  => '0'                         -- Synchronous preset input
      );


  RXIO_obufds : OBUFDS
    generic map (
      IOSTANDARD => "DEFAULT")
    port map (
      O  => RXIO_P,
      OB => RXIO_N,
      I  => rxio
      );

  main : process (txclk, rst)
  begin  -- process main
    if rst = '1' then                   -- asynchronous reset

      cs           <= none;
      txcodeerrreg <= (others => '1');
      encodece     <= '0';
    else
      if rising_edge(txclk) then
        cs <= ns;

        rxdinl <= RXDIN;
        rxkinl <= RXKIN;

        txdinl  <= TXDIN;
        txdinll <= txdinl;

        TXDOUT <= ltxdout;
        TXKOUT <= ltxkout;

        if rxcontrol = '0' then
          oll <= ol;
        else
          if forceerr = '1' then
            oll <= "0000000000";
          else
            oll <= "1011110000";
          end if;
        end if;

        txcodeerrreg <= (txcodeerrreg(62 downto 0) & txcodeerr);
        if rxsenden = '0' then
          encodece <= '0';
        else
          encodece <= not encodece;
        end if;


        if cs = lock then
          LINKLOCK <= '1';
        else
          LINKLOCK <= '0';
        end if;

        -- debugging
        if cs = lock then
          DEBUGOUT(0) <= '1';
          DEBUGOUT(1) <= '0';
        elsif cs = unlocked then
          DEBUGOUT(0) <= '1';
          DEBUGOUT(1) <= '1';
        else
          DEBUGOUT(0) <= '0';
          DEBUGOUT(1) <= '0';
        end if;

        DEBUGOUT(15 downto 8)  <= din;
        DEBUGOUT(2)            <= kin;
        DEBUGOUT(3)            <= encodece;
        DEBUGOUT(7 downto 4)   <= ldebugstate;
        DEBUGOUT(25 downto 16) <= ol;
        
      end if;
    end if;
  end process main;

  encrst <= '1' when cs = none else '0';


  rxclkproc : process(rxhbitclk)
    variable bitreg : std_logic_vector(4 downto 0) := "00001";

  begin
    if rising_edge(rxhbitclk) then
      bitreg := bitreg(0) & bitreg(4 downto 1);
      if bitreg(0) = '1' then
        sout <= oll;
      else
        sout <= "00" & sout(9 downto 2);
      end if;

    end if;

  end process rxclkproc;

  fsm : process (cs, ltxkout, txdinl, ltxdout, txcodeerrreg, txcodeerr)
  begin
    case cs is
      when none =>
        dsel        <= '1';
        forceerr    <= '0';
        rxcontrol   <= '0';
        rxsenden    <= '0';
        ldebugstate <= "0000";
        decodece <= '0'; 
        ns          <= sendsync;
        
      when sendsync =>
        dsel        <= '1';
        forceerr    <= '0';
        rxcontrol   <= '1';
        rxsenden    <= '0';
        ldebugstate <= "0001";
        decodece <= '0'; 
        if txdinl = "0110000011" or txdinl = "1001111100" then
          ns <= encst1;
        else
          ns <= sendsync;
        end if;
        
      when encst1 =>
        dsel        <= '1';
        forceerr    <= '0';
        rxcontrol   <= '0';
        rxsenden    <= '1';
        ldebugstate <= "0010";
        decodece <= '1'; 
        ns          <= encst2;
        

      when encst2 =>
        dsel        <= '1';
        forceerr    <= '0';
        rxcontrol   <= '0';
        rxsenden    <= '1';
        ldebugstate <= "0011";
        decodece <= '1'; 
        ns          <= waitup;
        

      when waitup =>
        dsel        <= '0';
        forceerr    <= '0';
        rxcontrol   <= '0';
        rxsenden    <= '1';
        ldebugstate <= "0100";
        decodece <= '1'; 
        if ltxdout = X"FE" and ltxkout = '1' then
          ns <= lock;
        else
          ns <= waitup;
        end if;

      when lock =>
        dsel        <= '0';
        forceerr    <= '0';
        rxcontrol   <= '0';
        rxsenden    <= '1';
        ldebugstate <= "0101";
        decodece <= '1'; 
        if txcodeerr = '1' then
          ns <= unlocked;
        else
          ns <= lock;
        end if;
        
      when unlocked =>
        dsel        <= '0';
        forceerr    <= '1';
        rxcontrol   <= '1';
        rxsenden    <= '1';
        ldebugstate <= "0110";
        decodece <= '0'; 
        ns          <= none;
        
      when others =>
        dsel        <= '0';
        forceerr    <= '0';
        rxcontrol   <= '0';
        rxsenden    <= '0';
        ldebugstate <= "1000";
        decodece <= '0'; 
        ns          <= none;
    end case;

  end process fsm;
end Behavioral;
