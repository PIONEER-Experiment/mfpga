-- Ethernet / IPbus diagnostics read over JTAG with a VIO (6.7.3).  Only built when ipbus_top's
-- DEBUG_VIO generic is non-zero (the top-level localparam DEBUG_ETH_VIO); release builds leave it at 0
-- and none of this, nor the vio_eth IP, is in the design.
--
-- Purpose: the board occasionally goes deaf after a SYS.RST (no IPbus, no ping) until it is
-- reconfigured.  When that happens IPbus cannot be used to look inside, but the JTAG hub still
-- can.  One read of this VIO in the Hardware Manager says which layer has stopped:
--   PHY / transceiver    status_vector bits (link, sync), resetdone, mmcm_locked, the userclk2
--                        heartbeat still counting?
--   MAC                  frames received / sent still counting while you ping the board?
--   IPbus core           IPbus packets received / sent (transactor) still counting?
--   resets               rst_ipb / rst_125 / sys_rst levels now, and how many SYS.RSTs so far
--
-- The VIO runs on clk_200 (the PLL on the 50 MHz oscillator), so it keeps working whatever the
-- Ethernet clocks are doing.  The counters are sampled asynchronously; an occasional torn read of a
-- counter that is counting is expected and harmless (read twice).  What matters is whether it moves.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity eth_debug is
port (
    clk_200      : in std_logic;     -- VIO clock (free running)
    mac_clk      : in std_logic;     -- Ethernet PHY userclk2, 125 MHz
    ipb_clk      : in std_logic;     -- IPbus clock
    phy_status   : in std_logic_vector(15 downto 0);   -- PCS/PMA status_vector (mac_clk)
    phy_resetdone: in std_logic;
    mmcm_locked  : in std_logic;
    ip_enable    : in std_logic;     -- i2c_startup_done: MAC / IP addresses valid
    rst_ipb      : in std_logic;
    rst_125      : in std_logic;
    sys_rst      : in std_logic;     -- control register bit 0 (SYS.RST) as written
    mac_rx_last  : in std_logic;     -- mac_clk
    mac_rx_error : in std_logic;
    mac_tx_last  : in std_logic;
    mac_tx_valid : in std_logic;
    mac_tx_ready : in std_logic;
    pkt_rx       : in std_logic;     -- ipbus_ctrl / transactor (ipb_clk): an IPbus packet received
    pkt_tx       : in std_logic      --                                  : an IPbus packet sent
);
end eth_debug;

architecture rtl of eth_debug is

    component vio_eth
    port (
        clk        : in std_logic;
        probe_in0  : in std_logic_vector(15 downto 0);
        probe_in1  : in std_logic_vector(7 downto 0);
        probe_in2  : in std_logic_vector(15 downto 0);
        probe_in3  : in std_logic_vector(15 downto 0);
        probe_in4  : in std_logic_vector(15 downto 0);
        probe_in5  : in std_logic_vector(15 downto 0);
        probe_in6  : in std_logic_vector(15 downto 0);
        probe_in7  : in std_logic_vector(15 downto 0);
        probe_in8  : in std_logic_vector(15 downto 0);
        probe_in9  : in std_logic_vector(15 downto 0)
    );
    end component;

    signal mac_rx_frames, mac_tx_frames, mac_rx_errors : unsigned(15 downto 0) := (others => '0');
    signal ipb_rx_pkts, ipb_tx_pkts, sysrst_count : unsigned(15 downto 0) := (others => '0');
    signal mac_beat, ipb_beat : unsigned(31 downto 0) := (others => '0');
    signal rst_ipb_d : std_logic := '0';
    signal flags : std_logic_vector(7 downto 0);

    attribute ASYNC_REG : string;
    signal flags_s1, flags_s2 : std_logic_vector(7 downto 0) := (others => '0');
    attribute ASYNC_REG of flags_s1 : signal is "TRUE";
    attribute ASYNC_REG of flags_s2 : signal is "TRUE";

begin

    -- MAC side: frames in and out, receive errors, a heartbeat
    pmac: process(mac_clk)
    begin
        if rising_edge(mac_clk) then
            mac_beat <= mac_beat + 1;
            if mac_rx_last = '1' then mac_rx_frames <= mac_rx_frames + 1; end if;
            if mac_rx_last = '1' and mac_rx_error = '1' then mac_rx_errors <= mac_rx_errors + 1; end if;
            if mac_tx_last = '1' and mac_tx_valid = '1' and mac_tx_ready = '1' then mac_tx_frames <= mac_tx_frames + 1; end if;
        end if;
    end process;

    -- IPbus side: packets the transactor took and sent, SYS.RST count, a heartbeat
    pipb: process(ipb_clk)
    begin
        if rising_edge(ipb_clk) then
            ipb_beat <= ipb_beat + 1;
            rst_ipb_d <= rst_ipb;
            if pkt_rx = '1' then ipb_rx_pkts <= ipb_rx_pkts + 1; end if;
            if pkt_tx = '1' then ipb_tx_pkts <= ipb_tx_pkts + 1; end if;
            if rst_ipb = '1' and rst_ipb_d = '0' then sysrst_count <= sysrst_count + 1; end if;
        end if;
    end process;

    flags <= phy_resetdone & mmcm_locked & phy_status(0) & phy_status(1) & ip_enable & rst_ipb & rst_125 & sys_rst;
    pflg: process(clk_200)
    begin
        if rising_edge(clk_200) then
            flags_s1 <= flags; flags_s2 <= flags_s1;
        end if;
    end process;

    vio: vio_eth port map (
        clk       => clk_200,
        probe_in0 => phy_status,                                  -- PCS/PMA status_vector: [0] link, [1] sync, [2] RUDI(/C/), [3] RUDI(/I/), [4] RUDI(invalid), [5] rx disparity err, [6] rx not-in-table
        probe_in1 => flags_s2,                                    -- [7] phy resetdone [6] mmcm_locked [5] link [4] sync [3] MAC/IP valid [2] rst_ipb [1] rst_125 [0] SYS.RST bit
        probe_in2 => std_logic_vector(mac_rx_frames),             -- frames received by the MAC (any: ARP, ping, IPbus)
        probe_in3 => std_logic_vector(mac_tx_frames),             -- frames sent by the MAC
        probe_in4 => std_logic_vector(mac_rx_errors),             -- received frames with an error
        probe_in5 => std_logic_vector(ipb_rx_pkts),               -- IPbus packets the transactor took
        probe_in6 => std_logic_vector(ipb_tx_pkts),               -- IPbus packets the transactor sent
        probe_in7 => std_logic_vector(sysrst_count),              -- SYS.RSTs (rst_ipb rising edges) since configuration
        probe_in8 => std_logic_vector(mac_beat(31 downto 16)),    -- userclk2 heartbeat (moves ~1900 counts/s if the PHY clock runs)
        probe_in9 => std_logic_vector(ipb_beat(31 downto 16))     -- clk_ipb heartbeat
    );

end rtl;
