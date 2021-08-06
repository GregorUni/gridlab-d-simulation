clear all;
format long g;

%% Most of the things you might want to change via a scripting mechanism are located in this section
%notes 
%in file wiredata are line_configurations and conductors configurations
%needed for line_configurations


% Directory for input files (CSVs)
% dir = '~\Anwendung\gridlabd\tools\IEEETest\4800Bus\CSV_Version';
% Directory for output of GLM files
dir2 = 'TestModel.glm';

% Power flow solver method
solver_method = 'NR';

% Start and stop times
start_date='''2012-04-08';
stop_date  = '''2014-04-08';
start_time='00:00:00''';
stop_time = '17:00:00''';
% timezone='PST+8PDT';

with_DR = 0; % do we want to include DR;


%% Some nominal voltage stuff for assigning flat start voltages
nom_volt1 = '7199.558';
nom_volt2 = '12470.00';
nom_volt3 = '69715.05';
nom_volt4 = '115000.00';


%% Load Lines.csv values

% Name1|From node2|Phases3|to node4|Phases5|Length6|Units7|Config8|Status9
fidLines = fopen('Lines.csv');
%Header1Lines = textscan(fidLines,'%s',1);
Header2Lines = textscan(fidLines,'%s %s %s %s %s %s %s %s ',1,'Delimiter',',');

RawLines = textscan(fidLines,'%s %s %s %s %s %n %s %s ','Delimiter',',');

% Load Transformers.csv values
% Name1|Phases2|From3|To4|primV5|secV6|MVA7|PrimConn8|SecConn9|%X10|%R11
fidTrans = fopen('Transformers.csv');
Header1Trans = textscan(fidTrans,'%s',1);
Header2Trans = textscan(fidTrans,'%s %s %s %s %s %s %s %s %s %s %s',2,'Delimiter',',');

RawTrans = textscan(fidTrans,'%s %n %s %s %n %n %n %s %s %n %n','Delimiter',',');

% Load Loads.csv values
% Name1|#ofPh|NameofBus3|Ph4|NomVolt5|Status6|Model7|Connect8|Power9|PF10
 fidTripLoads = fopen('Phases.csv');
 LoadPhases = textscan(fidTripLoads,'%s',200);
 
 fidcond = fopen('WireData.dss');
 Header1 = textscan(fidcond,'%s',4);

 % Values{1}-name | {2}-ohms/km | {3}-GMR in cm | {4}-outer rad? (cm)
 CondValues = textscan(fidcond,'%*s WireData.%s Rac=%n %*s GMRac=%n %*s Radius=%n %*s %*s %s');

Racunits = 'Ohm/km';
GMRunits = 'cm';

fclose('all');

NameLines = char(RawLines{1});
FromLines = char(RawLines{2});
PhasesLines = char(RawLines{3});
ToLines = char(RawLines{4});
LengthLines = (RawLines{6});
UnitLines = char(RawLines{7});
ConfigLines = char(RawLines{8});
% StatusLines = char(RawLines{9});

%  change the parameters for houses, lines and nodes.
EndLines = 2;
AmountHouses = 1;
EndLoadTrans =  1;
AmountNodes = 0;


%% Print to glm file
if strcmp(solver_method,'FBS')
    if (with_DR ~= 0)
        open_name = [dir2 '\IEEE_8500node_whouses_FBS_DR.glm'];
    else
        open_name = [dir2 '\IEEE_8500node_whouses_FBS.glm'];
    end
elseif strcmp(solver_method,'NR')
    if (with_DR ~= 0)
        open_name = ('Gridlabd_Model_NR.glm');
    else
        open_name = ('Gridlabd_Model_NR.glm');
    end
else
    fprintf('screw-up in naming of open file');
end

fid = fopen(open_name,'wt');

%% Header stuff and schedules
fprintf(fid,'//IEEE 8500 node test system.\n');
fprintf(fid,'//  Generated %s using Matlab %s.\n\n',datestr(clock),version);

fprintf(fid,'clock {\n');
% fprintf(fid,'     timezone %s;\n',timezone);
fprintf(fid,'     starttime %s %s;\n',start_date,start_time);
fprintf(fid,'     stoptime %s %s;\n',stop_date,stop_time);
fprintf(fid,'}\n\n');


%%
fprintf(fid,'module powerflow {\n');
fprintf(fid,'    solver_method %s;\n',solver_method);
fprintf(fid,'    line_limits FALSE;\n');
fprintf(fid,'    default_maximum_voltage_error 1e-4;\n');
fprintf(fid,'};\n');

    fprintf(fid,'module residential {\n');
    fprintf(fid,'     implicit_enduses NONE;\n');
    fprintf(fid,'ANSI_voltage_check FALSE;\n');
    fprintf(fid,'}\n');
    fprintf(fid,'module climate;\n');

fprintf(fid,'module tape;\n\n');
% fprintf(fid,'#include "recorders.glm";\n');
% fprintf(fid,'#include "schedules.glm";\n\n');


    fprintf(fid,'#set minimum_timestep=1800;\n');

fprintf(fid,'#set profiler=1;\n');
fprintf(fid,'#set relax_naming_rules=1;\n');
fprintf(fid,'#set suppress_repeat_messages=1;\n');
fprintf(fid,'#set savefile="8500_balanced_%s.xml";\n',solver_method);


fprintf(fid,'module market;\n\n');

fprintf(fid,'class auction {\n');
fprintf(fid,'    double current_price_mean_24h;\n');
fprintf(fid,'    double current_price_stdev_24h;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object auction {\n');
fprintf(fid,'    name Market_1;\n');
fprintf(fid,'    special_mode NONE;\n');
fprintf(fid,'    unit kW;\n');
fprintf(fid,'    period 300;\n');
fprintf(fid,'    init_price 30;\n');
fprintf(fid,'    init_stdev 5;\n');
fprintf(fid,'    capacity_reference_object HVMV_Sub;\n');
fprintf(fid,'    capacity_reference_property power_out_real;\n\n');
fprintf(fid,'    object player {\n');
fprintf(fid,'        property capacity_reference_bid_price;\n');
fprintf(fid,'        file Market/ExamplePrices2.player;\n');
fprintf(fid,'        loop 150;\n');
fprintf(fid,'    };\n\n');
fprintf(fid,'    max_capacity_reference_bid_quantity 500000;\n');
fprintf(fid,'    warmup 0;\n');
fprintf(fid,'}\n\n');
    


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Create Transformer objects -- only one transformer, so mostly by hand
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf(fid,'// Transformer and configuration at feeder\n\n');


fprintf(fid,'object transformer_configuration:27500 {\n');
fprintf(fid,'     connect_type DELTA_GWYE;\n');
fprintf(fid,'     name trans_config_1;\n');
fprintf(fid,'     install_type PADMOUNT;\n');
fprintf(fid,'     power_rating %5.0fkVA;\n',1000*RawTrans{7}(1));
fprintf(fid,'     primary_voltage %3.1fkV;\n',RawTrans{5}(1));
fprintf(fid,'     secondary_voltage %2.2fkV;\n',RawTrans{6}(1));
fprintf(fid,'     reactance %1.5f;\n',.01*RawTrans{10}(1));
fprintf(fid,'     resistance %1.5f;\n',.01*RawTrans{11}(1));
fprintf(fid,'}\n\n');

fprintf(fid,'object transformer {\n');
fprintf(fid,'     phases ABCN;\n');
fprintf(fid,'     name "%s";\n',char(RawTrans{1}(1)));
fprintf(fid,'     from "%s";\n',char(RawTrans{3}(1)));
fprintf(fid,'     to "%s";\n',char(RawTrans{4}(1)));
fprintf(fid,'     configuration trans_config_1;\n');
fprintf(fid,'}\n\n');

% One node object in regulators and HV needs to be manually generated
fprintf(fid,'object node {\n');
fprintf(fid,'     phases ABCN;\n');
fprintf(fid,'     name "regxfmr_HVMV_Sub_LSB";\n');
fprintf(fid,'     nominal_voltage %s;\n',nom_volt1);
fprintf(fid,'}\n\n');

fprintf(fid,'object node {\n');
fprintf(fid,'     phases ABCN;\n');
fprintf(fid,'     name "HVMV_Sub_HSB";\n');
fprintf(fid,'     bustype SWING;\n');
fprintf(fid,'     voltage_A 69512-0.7d;\n');    % Correct for missing 
fprintf(fid,'     voltage_B 69557-120.7d;\n');  % reactor
fprintf(fid,'     voltage_C 69595+119.3d;\n');
fprintf(fid,'     nominal_voltage 69512;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object node {\n');
fprintf(fid,'     phases ABCN;\n');
fprintf(fid,'     name "HVMV_Sub_48332";\n');
fprintf(fid,'     nominal_voltage 7199.558;\n');
fprintf(fid,'}\n');
fprintf(fid,'\n');

fprintf(fid,'object regulator {\n');
fprintf(fid,'     name "FEEDER_REG";\n');
fprintf(fid,'     phases ABCN;\n');
fprintf(fid,'     from "regxfmr_HVMV_Sub_LSB";\n');
fprintf(fid,'     to "_HVMV_Sub_LSB";\n');
fprintf(fid,'     configuration reg_config_1;\n');
fprintf(fid,'}\n');
fprintf(fid,'\n');

fprintf(fid,'object regulator_configuration {\n');
fprintf(fid,'     connect_type 1;\n');
fprintf(fid,'     name reg_config_1;\n');
fprintf(fid,'     Control OUTPUT_VOLTAGE;\n');
fprintf(fid,'     band_center 7500.0;\n');
fprintf(fid,'     band_width 120.0;\n');
fprintf(fid,'     time_delay 60.0;\n');
fprintf(fid,'     raise_taps 16;\n');
fprintf(fid,'     lower_taps 16;\n');
fprintf(fid,'     regulation 0.1;\n');
fprintf(fid,'     Type B;\n');
fprintf(fid,'}\n');
fprintf(fid,'\n');




%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Create Center-tap Transformer objects
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

 fprintf(fid,'// Center-tap transformer configurations\n\n');
 
 RHL = 0.006;
 RHT = 0.012;
 RLT = 0.012;
 
 XHL = 0.0204;
 XHT = 0.0204;
 XLT = 0.0136;
 
 XH = 0.5*(XHL+XHT-XLT);
 XL = 0.5*(XHL+XLT-XHT);
 XT = 0.5*(XLT+XHT-XHL);
 
fprintf(fid,'object transformer_configuration {           \n');
fprintf(fid,'     name "1515A";                           \n');
fprintf(fid,'     connect_type SINGLE_PHASE_CENTER_TAPPED;\n');
fprintf(fid,'     install_type POLETOP;                   \n');
fprintf(fid,'     primary_voltage 7200.0V;                \n');
fprintf(fid,'     secondary_voltage 120.0V;               \n');
fprintf(fid,'     power_rating 15.0kVA;                   \n');
fprintf(fid,'     powerA_rating 15.0kVA;                  \n');
fprintf(fid,'     impedance 0.006000+0.013600j;           \n');
fprintf(fid,'     impedance1 0.012000+0.006800j;          \n');
fprintf(fid,'     impedance2 0.012000+0.006800j;          \n');
fprintf(fid,'     shunt_impedance 1728000+691200j;        \n');
fprintf(fid,'}                                            \n');

fprintf(fid,'object transformer_configuration {           \n');
fprintf(fid,'     name "2525B";                           \n');
fprintf(fid,'     connect_type SINGLE_PHASE_CENTER_TAPPED;\n');
fprintf(fid,'     install_type POLETOP;                   \n');
fprintf(fid,'     primary_voltage 7200.0;                 \n');
fprintf(fid,'     secondary_voltage 120.0;                \n');
fprintf(fid,'     power_rating 25.0;                      \n');
fprintf(fid,'     powerB_rating 25.0;                     \n');
fprintf(fid,'     impedance 0.006+0.0136j;                \n');
fprintf(fid,'     impedance1 0.012+0.0204j;               \n');
fprintf(fid,'     impedance2 0.012+0.0204j;               \n');
fprintf(fid,'     shunt_impedance 1036800+414720j;        \n');
fprintf(fid,'}                                            \n');

fprintf(fid,'object transformer_configuration {           \n');
fprintf(fid,'     name "1515C";                           \n');
fprintf(fid,'     connect_type SINGLE_PHASE_CENTER_TAPPED;\n');
fprintf(fid,'     install_type POLETOP;                   \n');
fprintf(fid,'     primary_voltage 7200.0;                 \n');
fprintf(fid,'     secondary_voltage 120.0;                \n');
fprintf(fid,'     power_rating 15.0;                      \n');
fprintf(fid,'     powerC_rating 15.0;                     \n');
fprintf(fid,'     impedance 0.006+0.0136j;                \n');
fprintf(fid,'     impedance1 0.012+0.0204j;               \n');
fprintf(fid,'     impedance2 0.012+0.0204j;               \n');
fprintf(fid,'     shunt_impedance 1728000+691200j;        \n');
fprintf(fid,'}                                            \n');

fprintf(fid,'object transformer_configuration {           \n');
fprintf(fid,'     name "3838A";                           \n');
fprintf(fid,'     connect_type SINGLE_PHASE_CENTER_TAPPED;\n');
fprintf(fid,'     install_type POLETOP;                   \n');
fprintf(fid,'     primary_voltage 7200.0;                 \n');
fprintf(fid,'     secondary_voltage 120.0;                \n');
fprintf(fid,'     power_rating 37.5;                      \n');
fprintf(fid,'     powerA_rating 37.5;                     \n');
fprintf(fid,'     impedance 0.006+0.0136j;                \n');
fprintf(fid,'     impedance1 0.012+0.0204j;               \n');
fprintf(fid,'     impedance2 0.012+0.0204j;               \n');
fprintf(fid,'     shunt_impedance 691200+276480j;         \n');
fprintf(fid,'}                                            \n');

fprintf(fid,'object transformer_configuration {           \n');
fprintf(fid,'     name "1515B";                           \n');
fprintf(fid,'     connect_type SINGLE_PHASE_CENTER_TAPPED;\n');
fprintf(fid,'     install_type POLETOP;                   \n');
fprintf(fid,'     primary_voltage 7200.0;                 \n');
fprintf(fid,'     secondary_voltage 120.0;                \n');
fprintf(fid,'     power_rating 15.0;                      \n');
fprintf(fid,'     powerB_rating 15.0;                     \n');
fprintf(fid,'     impedance 0.006+0.0136j;                \n');
fprintf(fid,'     impedance1 0.012+0.0204j;               \n');
fprintf(fid,'     impedance2 0.012+0.0204j;               \n');
fprintf(fid,'     shunt_impedance 1728000+691200j;        \n');
fprintf(fid,'}                                            \n');

fprintf(fid,'object transformer_configuration {           \n');  
fprintf(fid,'     name "5050A";                           \n');
fprintf(fid,'     connect_type SINGLE_PHASE_CENTER_TAPPED;\n');
fprintf(fid,'     install_type POLETOP;                   \n');
fprintf(fid,'     primary_voltage 7200.0;                 \n');
fprintf(fid,'     secondary_voltage 120.0;                \n');
fprintf(fid,'     power_rating 50.0;                      \n');
fprintf(fid,'     powerA_rating 50.0;                     \n');
fprintf(fid,'     impedance 0.006+0.0136j;                \n');
fprintf(fid,'     impedance1 0.012+0.0204j;               \n');
fprintf(fid,'     impedance2 0.012+0.0204j;               \n');
fprintf(fid,'     shunt_impedance 518400+207360j;         \n');
fprintf(fid,'}                                            \n');

fprintf(fid,'object transformer_configuration {           \n');
fprintf(fid,'     name "5050B";                           \n');
fprintf(fid,'     connect_type SINGLE_PHASE_CENTER_TAPPED;\n');
fprintf(fid,'     install_type POLETOP;                   \n');
fprintf(fid,'     primary_voltage 7200.0;                 \n');
fprintf(fid,'     secondary_voltage 120.0;                \n');
fprintf(fid,'     power_rating 50.0;                      \n');
fprintf(fid,'     powerB_rating 50.0;                     \n');
fprintf(fid,'     impedance 0.006+0.0136j;                \n');
fprintf(fid,'     impedance1 0.012+0.0204j;               \n');
fprintf(fid,'     impedance2 0.012+0.0204j;               \n');
fprintf(fid,'     shunt_impedance 518400+207360j;         \n');
fprintf(fid,'}                                            \n');

fprintf(fid,'object transformer_configuration {           \n');
fprintf(fid,'     name "5050C";                           \n');
fprintf(fid,'     connect_type SINGLE_PHASE_CENTER_TAPPED;\n');
fprintf(fid,'     install_type POLETOP;                   \n');
fprintf(fid,'     primary_voltage 7200.0;                 \n');
fprintf(fid,'     secondary_voltage 120.0;                \n');
fprintf(fid,'     power_rating 50.0;                      \n');
fprintf(fid,'     powerC_rating 50.0;                     \n');
fprintf(fid,'     impedance 0.006+0.0136j;                \n');
fprintf(fid,'     impedance1 0.012+0.0204j;               \n');
fprintf(fid,'     impedance2 0.012+0.0204j;               \n');
fprintf(fid,'     shunt_impedance 518400+207360j;         \n');
fprintf(fid,'}                                            \n');

fprintf(fid,'object transformer_configuration {           \n');
fprintf(fid,'     name "1010A";                           \n');
fprintf(fid,'     connect_type SINGLE_PHASE_CENTER_TAPPED;\n');
fprintf(fid,'     install_type POLETOP;                   \n');
fprintf(fid,'     primary_voltage 7200.0;                 \n');
fprintf(fid,'     secondary_voltage 120.0;                \n');
fprintf(fid,'     power_rating 10.0;                      \n');
fprintf(fid,'     powerA_rating 10.0;                     \n');
fprintf(fid,'     impedance 0.006+0.0136j;                \n');
fprintf(fid,'     impedance1 0.012+0.0204j;               \n');
fprintf(fid,'     impedance2 0.012+0.0204j;               \n');
fprintf(fid,'     shunt_impedance 2592000+1036800j;       \n');
fprintf(fid,'}                                            \n');

fprintf(fid,'object transformer_configuration {           \n');
fprintf(fid,'     name "1010B";                           \n');
fprintf(fid,'     connect_type SINGLE_PHASE_CENTER_TAPPED;\n');
fprintf(fid,'     install_type POLETOP;                   \n');
fprintf(fid,'     primary_voltage 7200.0;                 \n');
fprintf(fid,'     secondary_voltage 120.0;                \n');
fprintf(fid,'     power_rating 10.0;                      \n');
fprintf(fid,'     powerB_rating 10.0;                     \n');
fprintf(fid,'     impedance 0.006+0.0136j;                \n');
fprintf(fid,'     impedance1 0.012+0.0204j;               \n');
fprintf(fid,'     impedance2 0.012+0.0204j;               \n');
fprintf(fid,'     shunt_impedance 2592000+1036800j;       \n');
fprintf(fid,'}                                            \n');

fprintf(fid,'object transformer_configuration {           \n');
fprintf(fid,'     name "2525A";                           \n');
fprintf(fid,'     connect_type SINGLE_PHASE_CENTER_TAPPED;\n');
fprintf(fid,'     install_type POLETOP;                   \n');
fprintf(fid,'     primary_voltage 7200.0;                 \n');
fprintf(fid,'     secondary_voltage 120.0;                \n');
fprintf(fid,'     power_rating 25.0;                      \n');
fprintf(fid,'     powerA_rating 25.0;                     \n');
fprintf(fid,'     impedance 0.006+0.0136j;                \n');
fprintf(fid,'     impedance1 0.012+0.0204j;               \n');
fprintf(fid,'     impedance2 0.012+0.0204j;               \n');
fprintf(fid,'     shunt_impedance 1036800+414720j;        \n');
fprintf(fid,'}                                            \n');

fprintf(fid,'object transformer_configuration {           \n');
fprintf(fid,'     name "1010C";                           \n');
fprintf(fid,'     connect_type SINGLE_PHASE_CENTER_TAPPED;\n');
fprintf(fid,'     install_type POLETOP;                   \n');
fprintf(fid,'     primary_voltage 7200.0;                 \n');
fprintf(fid,'     secondary_voltage 120.0;                \n');
fprintf(fid,'     power_rating 10.0;                      \n');
fprintf(fid,'     powerC_rating 10.0;                     \n');
fprintf(fid,'     impedance 0.006+0.0136j;                \n');
fprintf(fid,'     impedance1 0.012+0.0204j;               \n');
fprintf(fid,'     impedance2 0.012+0.0204j;               \n');
fprintf(fid,'     shunt_impedance 2592000+1036800j;       \n');
fprintf(fid,'}                                            \n');

fprintf(fid,'object transformer_configuration {           \n');
fprintf(fid,'     name "2525C";                           \n');
fprintf(fid,'     connect_type SINGLE_PHASE_CENTER_TAPPED;\n');
fprintf(fid,'     install_type POLETOP;                   \n');
fprintf(fid,'     primary_voltage 7200.0;                 \n');
fprintf(fid,'     secondary_voltage 120.0;                \n');
fprintf(fid,'     power_rating 25.0;                      \n');
fprintf(fid,'     powerC_rating 25.0;                     \n');
fprintf(fid,'     impedance 0.006+0.0136j;                \n');
fprintf(fid,'     impedance1 0.012+0.0204j;               \n');
fprintf(fid,'     impedance2 0.012+0.0204j;               \n');
fprintf(fid,'     shunt_impedance 1036800+414720j;        \n');
fprintf(fid,'}                                            \n');

fprintf(fid,'object transformer_configuration {           \n');
fprintf(fid,'     name "7575C";                           \n');
fprintf(fid,'     connect_type SINGLE_PHASE_CENTER_TAPPED;\n');
fprintf(fid,'     install_type POLETOP;                   \n');
fprintf(fid,'     primary_voltage 7200.0;                 \n');
fprintf(fid,'     secondary_voltage 120.0;                \n');
fprintf(fid,'     power_rating 75.0;                      \n');
fprintf(fid,'     powerC_rating 75.0;                     \n');
fprintf(fid,'     impedance 0.006+0.0136j;                \n');
fprintf(fid,'     impedance1 0.012+0.0204j;               \n');
fprintf(fid,'     impedance2 0.012+0.0204j;               \n');
fprintf(fid,'     shunt_impedance 345600+138240j;         \n');
fprintf(fid,'}                                            \n');

fprintf(fid,'object transformer_configuration {           \n');
fprintf(fid,'     name "3838C";                           \n');
fprintf(fid,'     connect_type SINGLE_PHASE_CENTER_TAPPED;\n');
fprintf(fid,'     install_type POLETOP;                   \n');
fprintf(fid,'     primary_voltage 7200.0;                 \n');
fprintf(fid,'     secondary_voltage 120.0;                \n');
fprintf(fid,'     power_rating 37.5;                      \n');
fprintf(fid,'     powerC_rating 37.5;                     \n');
fprintf(fid,'     impedance 0.006+0.0136j;                \n');
fprintf(fid,'     impedance1 0.012+0.0204j;               \n');
fprintf(fid,'     impedance2 0.012+0.0204j;               \n');
fprintf(fid,'     shunt_impedance 691200+276480j;         \n');
fprintf(fid,'}                                            \n');

fprintf(fid,'object transformer_configuration {           \n');
fprintf(fid,'     name "55B";                             \n');
fprintf(fid,'     connect_type SINGLE_PHASE_CENTER_TAPPED;\n');
fprintf(fid,'     install_type POLETOP;                   \n');
fprintf(fid,'     primary_voltage 7200.0;                 \n');
fprintf(fid,'     secondary_voltage 120.0;                \n');
fprintf(fid,'     power_rating 5.0;                       \n');
fprintf(fid,'     powerB_rating 5.0;                      \n');
fprintf(fid,'     impedance 0.006+0.0136j;                \n');
fprintf(fid,'     impedance1 0.012+0.0204j;               \n');
fprintf(fid,'     impedance2 0.012+0.0204j;               \n');
fprintf(fid,'     shunt_impedance 5184000+2073600j;       \n');
fprintf(fid,'}                                            \n');

fprintf(fid,'object transformer_configuration {           \n');
fprintf(fid,'     name "3838B";                           \n');
fprintf(fid,'     connect_type SINGLE_PHASE_CENTER_TAPPED;\n');
fprintf(fid,'     install_type POLETOP;                   \n');
fprintf(fid,'     primary_voltage 7200.0;                 \n');
fprintf(fid,'     secondary_voltage 120.0;                \n');
fprintf(fid,'     power_rating 37.5;                      \n');
fprintf(fid,'     powerB_rating 37.5;                     \n');
fprintf(fid,'     impedance 0.006+0.0136j;                \n');
fprintf(fid,'     impedance1 0.012+0.0204j;               \n');
fprintf(fid,'     impedance2 0.012+0.0204j;               \n');
fprintf(fid,'     shunt_impedance 691200+276480j;         \n');
fprintf(fid,'}                                            \n');

fprintf(fid,'object transformer_configuration {           \n');
fprintf(fid,'     name "7575A";                           \n');
fprintf(fid,'     connect_type SINGLE_PHASE_CENTER_TAPPED;\n');
fprintf(fid,'     install_type POLETOP;                   \n');
fprintf(fid,'     primary_voltage 7200.0;                 \n');
fprintf(fid,'     secondary_voltage 120.0;                \n');
fprintf(fid,'     power_rating 75.0;                      \n');
fprintf(fid,'     powerA_rating 75.0;                     \n');
fprintf(fid,'     impedance 0.006+0.0136j;                \n');
fprintf(fid,'     impedance1 0.012+0.0204j;               \n');
fprintf(fid,'     impedance2 0.012+0.0204j;               \n');
fprintf(fid,'     shunt_impedance 345600+138240j;         \n');
fprintf(fid,'}                                            \n');

fprintf(fid,'object transformer_configuration {           \n');
fprintf(fid,'     name "7575B";                           \n');
fprintf(fid,'     connect_type SINGLE_PHASE_CENTER_TAPPED;\n');
fprintf(fid,'     install_type PADMOUNT;                  \n');
fprintf(fid,'     primary_voltage 7200.0;                 \n');
fprintf(fid,'     secondary_voltage 120.0;                \n');
fprintf(fid,'     power_rating 75.0;                      \n');
fprintf(fid,'     powerB_rating 75.0;                     \n');
fprintf(fid,'     impedance 0.006+0.0136j;                \n');
fprintf(fid,'     impedance1 0.012+0.0204j;               \n');
fprintf(fid,'     impedance2 0.012+0.0204j;               \n');
fprintf(fid,'     shunt_impedance 345600+138240j;         \n');
fprintf(fid,'}                                            \n');


fprintf(fid,'object transformer_configuration {           \n');
fprintf(fid,'     name "55A";                             \n');
fprintf(fid,'     connect_type SINGLE_PHASE_CENTER_TAPPED;\n');
fprintf(fid,'     install_type POLETOP;                   \n');
fprintf(fid,'     primary_voltage 7200.0;                 \n');
fprintf(fid,'     secondary_voltage 120.0;                \n');
fprintf(fid,'     power_rating 5.0;                       \n');
fprintf(fid,'     powerA_rating 5.0;                      \n');
fprintf(fid,'     impedance 0.006+0.0136j;                \n');
fprintf(fid,'     impedance1 0.012+0.0204j;               \n');
fprintf(fid,'     impedance2 0.012+0.0204j;               \n');
fprintf(fid,'     shunt_impedance 5184000+2073600j;       \n');
fprintf(fid,'}                                            \n');

fprintf(fid,'object transformer_configuration {           \n');  
fprintf(fid,'     name "250250A";                         \n');
fprintf(fid,'     connect_type SINGLE_PHASE_CENTER_TAPPED;\n');
fprintf(fid,'     install_type POLETOP;                   \n');
fprintf(fid,'     primary_voltage 7200.0;                 \n');
fprintf(fid,'     secondary_voltage 120.0;                \n');
fprintf(fid,'     power_rating 250.0;                     \n');
fprintf(fid,'     powerA_rating 250.0;                    \n');
fprintf(fid,'     impedance 0.006+0.0136j;                \n');
fprintf(fid,'     impedance1 0.012+0.0204j;               \n');
fprintf(fid,'     impedance2 0.012+0.0204j;               \n');
fprintf(fid,'     shunt_impedance 103680+41472j;          \n');
fprintf(fid,'}                                            \n');

fprintf(fid,'object transformer_configuration {           \n');
fprintf(fid,'     name "250250B";                         \n');
fprintf(fid,'     connect_type SINGLE_PHASE_CENTER_TAPPED;\n');
fprintf(fid,'     install_type POLETOP;                   \n');
fprintf(fid,'     primary_voltage 7200.0;                 \n');
fprintf(fid,'     secondary_voltage 120.0;                \n');
fprintf(fid,'     power_rating 250.0;                     \n');
fprintf(fid,'     powerB_rating 250.0;                    \n');
fprintf(fid,'     impedance 0.006+0.0136j;                \n');
fprintf(fid,'     impedance1 0.012+0.0204j;               \n');
fprintf(fid,'     impedance2 0.012+0.0204j;               \n');
fprintf(fid,'     shunt_impedance 103680+41472j;          \n');
fprintf(fid,'}                                            \n');

fprintf(fid,'object transformer_configuration {           \n');
fprintf(fid,'     name "250250C";                         \n');
fprintf(fid,'     connect_type SINGLE_PHASE_CENTER_TAPPED;\n');
fprintf(fid,'     install_type POLETOP;                   \n');
fprintf(fid,'     primary_voltage 7200.0;                 \n');
fprintf(fid,'     secondary_voltage 120.0;                \n');
fprintf(fid,'     power_rating 250.0;                     \n');
fprintf(fid,'     powerC_rating 250.0;                    \n');
fprintf(fid,'     impedance 0.006+0.0136j;                \n');
fprintf(fid,'     impedance1 0.012+0.0204j;               \n');
fprintf(fid,'     impedance2 0.012+0.0204j;               \n');
fprintf(fid,'     shunt_impedance 103680+41472j;          \n');
fprintf(fid,'}                                            \n');

fprintf(fid,'object transformer_configuration {           \n');
fprintf(fid,'     name "100100B";                         \n');
fprintf(fid,'     connect_type SINGLE_PHASE_CENTER_TAPPED;\n');
fprintf(fid,'     install_type POLETOP;                   \n');
fprintf(fid,'     primary_voltage 7200.0;                 \n');
fprintf(fid,'     secondary_voltage 120.0;                \n');
fprintf(fid,'     power_rating 100.0;                     \n');
fprintf(fid,'     powerB_rating 100.0;                    \n');
fprintf(fid,'     impedance 0.006+0.0136j;                \n');
fprintf(fid,'     impedance1 0.012+0.0204j;               \n');
fprintf(fid,'     impedance2 0.012+0.0204j;               \n');
fprintf(fid,'     shunt_impedance 259200+103680j;         \n');
fprintf(fid,'}                                            \n');

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Create Triplex-Load objects
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fprintf(fid,'// Triplex Node Objects with loads\n\n');
fprintf(fid,'class player {\n');
fprintf(fid,'      double value;\n');
fprintf(fid,'}\n');

total_houses = 0;

    disp('Generating houses...');
    total_houses = 0;
    floor_area_large = 0;
    floor_area_small = 1000000;
    
    % Make sure it's only psuedo-randomized, but repeatable
    s2 = RandStream.create('mrg32k3a','NumStreams',3,'StreamIndices',2);
    RandStream.setGlobalStream(s2);

    for i=1:AmountHouses
        
        Tph = char(LoadPhases{1}(i));
        PhLoad = Tph(1);
        fprintf(fid,'object node {\n');
        fprintf(fid,'phases ABC;\n');
        fprintf(fid,'name "node_%d";\n',i);
        fprintf(fid,'nominal_voltage 7199.558;\n');
        fprintf(fid,'}\n');
        fprintf(fid,'\n');
     
        fprintf(fid,'object transformer { \n');
        fprintf(fid,'     name transformer_%d; \n',i);
        fprintf(fid,'     phases %sS;\n',PhLoad);
        fprintf(fid,'     from "node_%d";\n',i);
        fprintf(fid,'     to "tnode_%d";\n',i);
        fprintf(fid,'     configuration "7575%s";\n',PhLoad);
        fprintf(fid,'}\n');
        
        fprintf(fid,'object triplex_node {\n');
        fprintf(fid,'     name "tnode_%d";\n',i);
        fprintf(fid,'     nominal_voltage 120;\n');
        fprintf(fid,'     phases %sS;\n\n',PhLoad);
        fprintf(fid,'}\n\n');
  
%         fprintf(fid,'     // Converted from load: %.1f+%.1fj\n',reload,imload);
            
     fprintf(fid,'object recorder {\n');
     fprintf(fid,'     name "Recorder%d";\n',i);
     fprintf(fid,'     parent "meter_%d";\n',i);
     fprintf(fid,'     interval 1800;\n');
     fprintf(fid,'     property measured_real_energy,measured_power,measured_real_power,measured_demand,monthly_bill,price;\n');
     fprintf(fid,'     file strom/strom_%d.csv;\n',i);
     fprintf(fid,'}\n');
     
       fprintf(fid,'object triplex_line { \n');
       fprintf(fid,'     name "tline_%d";  \n',i);
       fprintf(fid,'     phases %sS;\n',PhLoad);
       fprintf(fid,'     from "tnode_%d";\n',i);
       fprintf(fid,'     to "meter_%d";\n',i);
       fprintf(fid,'     length 15;\n');
       fprintf(fid,'     configuration "4/0Triplex";\n');
       fprintf(fid,'}\n');
     
      fprintf(fid,'object triplex_meter {  \n');
      fprintf(fid,'     name "meter_%d";\n',i);
      fprintf(fid,'     phases %sS;\n',PhLoad);
      fprintf(fid,'bill_mode HOURLY;\n');
      fprintf(fid,'power_market Market_1;\n');    
      fprintf(fid,' bill_day 1;\n');
      fprintf(fid,'     voltage_1 120; \n');
      fprintf(fid,'     voltage_2 120;\n');
      fprintf(fid,'     voltage_N 0;    \n');
      fprintf(fid,'     nominal_voltage 120;  \n');
      fprintf(fid,'} \n');
      
        
            fprintf(fid,'object house {\n');
            fprintf(fid,'  parent "meter_%d";\n',i);
            fprintf(fid,'  name "house_%d";\n',i);
            
            ti = floor(5*rand(1)) + 3; % can use to shift thermal integrity
            
            if (ti > 6)
                ti = 6;
            end
	    fprintf(fid,'  heating_system_type NONE;\n');
            fprintf(fid,'  cooling_system_type NONE;\n');
              
            fprintf(fid,'  object ZIPload {\n');
            fprintf(fid,'         name "house%d_load";\n',i);
            fprintf(fid,'         base_power LOAD%d_player.value;\n',i);
            fprintf(fid,'  };\n\n');
            
            fprintf(fid,'  }\n\n');
                
            fprintf(fid,'object player {\n');
            fprintf(fid,'name LOAD%d_player;\n',i);
            fprintf(fid,'file player/Load_profile_%d.player;\n',i);
            fprintf(fid,'}\n\n');
    end 

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Create Node objects
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
disp('Printing nodes - this will take some time...');
fprintf(fid,'// Node Objects\n\n');

% Go through 'From' node list, eliminate any repeats
n=0;
for i=1:EndLines
    stop = 0;
    phase = char(RawLines{3}(i));
    phasebit = 0;
    
    if ~isempty(findstr(phase,'A'))
        phasebit = phasebit + 4;
    end
    if ~isempty(findstr(phase,'B'))
        phasebit = phasebit + 2;
    end
    if ~isempty(findstr(phase,'C'))
        phasebit = phasebit + 1;
    end
    
    for m=1:n
        if (strcmp(RawLines{2}(i),Node_Name{1}(m)))
            stop = 1;
            phasebit = bitor(phasebit,Node_Phase{1}(m));
            Node_Phase{1}(m) = phasebit;
            m=n;
        end 
    end
    if stop~=1
        n=n+1;
        Node_Name{1}(n) = RawLines{2}(i);
        Node_Phase{1}(n) = phasebit;
    end
end
% Go through 'to' node list
end_last = n;
for i=(EndLines+1):(EndLines*2)
    stop = 0;
    phase = char(RawLines{3}(i-EndLines));
    phasebit = 0;
    
    if ~isempty(findstr(phase,'A'))
        phasebit = phasebit + 4;
    end
    if ~isempty(findstr(phase,'B'))
        phasebit = phasebit + 2;
    end
    if ~isempty(findstr(phase,'C'))
        phasebit = phasebit + 1;
    end
    
    for m=1:n
        if (strcmp(RawLines{4}(i-EndLines),Node_Name{1}(m)))
            stop = 1;
            phasebit = bitor(phasebit,Node_Phase{1}(m));
            Node_Phase{1}(m) = phasebit;
            m=n;
        elseif (RawLines{6}(i-EndLines)==0.01||RawLines{6}(i-EndLines)==0.001)
            stop = 1;
            m = n;
        end
    end 
    if stop~=1
        n=n+1;
        Node_Name{1}(n) = RawLines{4}(i-EndLines);
        Node_Phase{1}(n) = phasebit;
    end
end
% Print Nodes, but override all of the capacitor nodes to be three phase
for i=1:length(Node_Name{1})-1
    phasebit = Node_Phase{1}(i);
    
    switch phasebit
        case 1
            phase = 'C';
        case 2
            phase = 'B';
        case 3
            phase = 'BC';
        case 4
            phase = 'A';
        case 5
            phase = 'AC';
        case 6 
            phase = 'AB';
        case 7
            phase = 'ABC';
    end
    
    if (~isempty(findstr(char(Node_Name{1}(i)),'Q'))||(~isempty(findstr(char(Node_Name{1}(i)),'L2823592')))) 
        fprintf(fid,'object node {\n');
        fprintf(fid,'     phases ABCN;\n');
        fprintf(fid,'     name "%s";\n',char(Node_Name{1}(i)));
        fprintf(fid,'     nominal_voltage %s;\n',nom_volt1);
        fprintf(fid,'}\n\n');
    elseif (~isempty(findstr(char(Node_Name{1}(i)),'193-48013'))||(~isempty(findstr(char(Node_Name{1}(i)),'E182745')))||(~isempty(findstr(char(Node_Name{1}(i)),'193-51796')))) 
        % Some weird switch nodes that only need one phase attached
        fprintf(fid,'object node {\n');
        fprintf(fid,'     phases AN;\n');
        fprintf(fid,'     name "%s";\n',char(Node_Name{1}(i)));
        fprintf(fid,'     nominal_voltage %s;\n',nom_volt1);
        fprintf(fid,'}\n\n');
    else
        fprintf(fid,'object node {\n');
        fprintf(fid,'     phases %sN;\n',phase);
        fprintf(fid,'     name "%s";\n',char(Node_Name{1}(i)));
        fprintf(fid,'     nominal_voltage %s;\n',nom_volt1);
        fprintf(fid,'}\n\n');
    end
end

    for j=1:AmountNodes
         fprintf(fid,'object node {\n');
         fprintf(fid,'     phases %sN;\n',phase);
         fprintf(fid,'     name "power_node_%d";\n',j);
         fprintf(fid,'     nominal_voltage %s;\n',nom_volt1);
         fprintf(fid,'}\n\n');
    end

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Create Line and Conductor Configurations
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fprintf(fid,'// Overhead Line Conductors and configurations.\n');
disp('Printing lines and conductors...');
%Print the conductors that are needed
 for i = 1:length(CondValues{1})
     if (strcmp(char(CondValues{1}(i)),'397_ACSR')||strcmp(char(CondValues{1}(i)),'2/0_ACSR')||strcmp(char(CondValues{1}(i)),'4_ACSR')||strcmp(char(CondValues{1}(i)),'2_ACSR')||strcmp(char(CondValues{1}(i)),'1/0_ACSR')||strcmp(char(CondValues{1}(i)),'4_WPAL')||strcmp(char(CondValues{1}(i)),'1/0_TPX')||strcmp(char(CondValues{1}(i)),'4/0_TPX')||strcmp(char(CondValues{1}(i)),'4_DPX')||strcmp(char(CondValues{1}(i)),'1/0_3W_CS')||strcmp(char(CondValues{1}(i)),'4_TPX')||strcmp(char(CondValues{1}(i)),'6_WPAL')||strcmp(char(CondValues{1}(i)),'2_WPAL')||strcmp(char(CondValues{1}(i)),'2/0_WPAL')||strcmp(char(CondValues{1}(i)),'DEFAULT')||strcmp(char(CondValues{1}(i)),'600_CU'))
         fprintf(fid,'object overhead_line_conductor {\n');
         fprintf(fid,'     name "%s";\n',char(CondValues{1}(i)));
         fprintf(fid,'     geometric_mean_radius %1.6f%s;\n',CondValues{3}(i),GMRunits);
         fprintf(fid,'     resistance %1.6f%s;\n',CondValues{2}(i),Racunits);
         
             [~,temp_rating] = strtok(CondValues{5}(i),'=');
             [temp_rating,~] = strtok(temp_rating,'=');
             temp_rating = str2double(temp_rating);
         fprintf(fid,'     rating.summer.emergency %.0f A;\n',temp_rating);
         fprintf(fid,'     rating.summer.continuous %.0f A;\n',temp_rating);
         fprintf(fid,'     rating.winter.emergency %.0f A;\n',temp_rating);
         fprintf(fid,'     rating.winter.continuous %.0f A;\n',temp_rating);
         fprintf(fid,'}\n\n');
     end
 end

% Create line spacings 
fprintf(fid,'object line_spacing {\n');
fprintf(fid,'     name SinglePhase1A;\n');
fprintf(fid,'     distance_AN 2.3062m;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_spacing {\n');
fprintf(fid,'     name SinglePhase1B;\n');
fprintf(fid,'     distance_BN 2.3062m;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_spacing {\n');
fprintf(fid,'     name SinglePhase1C;\n');
fprintf(fid,'     distance_CN 2.3062m;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_spacing {\n');
fprintf(fid,'     name TwoPhase1AC;\n');
fprintf(fid,'     distance_AC 1.2192m;\n');
fprintf(fid,'     distance_CN 1.5911m;\n');
fprintf(fid,'     distance_AN 1.70388m;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_spacing {\n');
fprintf(fid,'     name ThreePhase1;\n');
fprintf(fid,'     distance_AB 0.97584m;\n');
fprintf(fid,'     distance_AC 1.2192m;\n');
fprintf(fid,'     distance_BC 0.762m;\n');
fprintf(fid,'     distance_BN 2.1336m;\n');
fprintf(fid,'     distance_AN 1.70388m;\n');
fprintf(fid,'     distance_CN 1.5911m;\n');
fprintf(fid,'}\n\n');

% Create all of the line configurations (67 of them + 3 oddballs)
fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x4_ACSRx4_ACSR";\n');
fprintf(fid,'     conductor_B "4_ACSR";\n');
fprintf(fid,'     conductor_N "4_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-xx4_ACSR4_ACSR";\n');
fprintf(fid,'     conductor_C "4_ACSR";\n');
fprintf(fid,'     conductor_N "4_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1C;\n');
fprintf(fid,'}\n\n');
                          
fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x2_ACSRx2_ACSR";\n');
fprintf(fid,'     conductor_B "2_ACSR";\n');
fprintf(fid,'     conductor_N "2_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x4_ACSRx4_WPAL";\n');
fprintf(fid,'     conductor_B "4_ACSR";\n');
fprintf(fid,'     conductor_N "4_WPAL";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-2/0_ACSR2/0_ACSR2/0_ACSR2_ACSR";\n');
fprintf(fid,'     conductor_A "2/0_ACSR";\n');
fprintf(fid,'     conductor_B "2/0_ACSR";\n');
fprintf(fid,'     conductor_C "2/0_ACSR";\n');
fprintf(fid,'     conductor_N "2_ACSR";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-4_ACSR4_ACSR4_ACSR4_ACSR";\n');
fprintf(fid,'     conductor_A "4_ACSR";\n');
fprintf(fid,'     conductor_B "4_ACSR";\n');
fprintf(fid,'     conductor_C "4_ACSR";\n');
fprintf(fid,'     conductor_N "4_ACSR";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-4_WPALxx2_WPAL";\n');
fprintf(fid,'     conductor_A "4_ACSR";\n');
fprintf(fid,'     conductor_N "4_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-4_ACSR2_ACSR2_ACSR4_WPAL";\n');
fprintf(fid,'     conductor_A "4_ACSR";\n');
fprintf(fid,'     conductor_B "2_ACSR";\n');
fprintf(fid,'     conductor_C "2_ACSR";\n');
fprintf(fid,'     conductor_N "4_WPAL";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-4_ACSRxx4_ACSR";\n');
fprintf(fid,'     conductor_A "4_ACSR";\n');
fprintf(fid,'     conductor_N "4_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-4_ACSR4_ACSR4_ACSR4_WPAL";\n');
fprintf(fid,'     conductor_A "4_ACSR";\n');
fprintf(fid,'     conductor_B "4_ACSR";\n');
fprintf(fid,'     conductor_C "4_ACSR";\n');
fprintf(fid,'     conductor_N "4_WPAL";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-2_ACSRxx2_ACSR";\n');
fprintf(fid,'     conductor_A "2_ACSR";\n');
fprintf(fid,'     conductor_N "2_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-4_WPALxx4_ACSR";\n');
fprintf(fid,'     conductor_A "4_WPAL";\n');
fprintf(fid,'     conductor_N "4_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-397_ACSR397_ACSR397_ACSR2/0_ACSR";\n');
fprintf(fid,'     conductor_A "397_ACSR";\n');	
fprintf(fid,'     conductor_B "397_ACSR";\n');
fprintf(fid,'     conductor_C "397_ACSR";\n');
fprintf(fid,'     conductor_N "2/0_ACSR";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

% Page 2 
fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-2_ACSRxx4_ACSR";\n');
fprintf(fid,'     conductor_A "2_ACSR";\n');
fprintf(fid,'     conductor_N "4_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-xx2_ACSR2_ACSR";\n');
fprintf(fid,'     conductor_C "2_ACSR";\n');
fprintf(fid,'     conductor_N "2_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1C;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-xx4_WPAL4_WPAL";\n');
fprintf(fid,'     conductor_C "4_WPAL";\n');
fprintf(fid,'     conductor_N "4_WPAL";\n');
fprintf(fid,'     spacing SinglePhase1C;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x4_WPALx4_WPAL";\n');
fprintf(fid,'     conductor_B "4_WPAL";\n');
fprintf(fid,'     conductor_N "4_WPAL";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-xx4_WPAL4_ACSR";\n');
fprintf(fid,'     conductor_C "4_WPAL";\n');
fprintf(fid,'     conductor_N "4_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1C;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x2_ACSRx1/0_TPX";\n');
fprintf(fid,'     conductor_B "2_ACSR";\n');
fprintf(fid,'     conductor_N "1/0_TPX";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-4_ACSRxx4_WPAL";\n');
fprintf(fid,'     conductor_A "4_ACSR";\n');
fprintf(fid,'     conductor_N "4_WPAL";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-xx4_ACSR1/0_TPX";\n');
fprintf(fid,'     conductor_C "4_ACSR";\n');
fprintf(fid,'     conductor_N "1/0_TPX";\n');
fprintf(fid,'     spacing SinglePhase1C;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-4_WPAL4_WPAL4_WPAL4_ACSR";\n');
fprintf(fid,'     conductor_A "4_WPAL";\n');
fprintf(fid,'     conductor_B "4_WPAL";\n');
fprintf(fid,'     conductor_C "4_WPAL";\n');
fprintf(fid,'     conductor_N "4_ACSR";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x4_WPALx4_ACSR";\n');
fprintf(fid,'     conductor_B "4_WPAL";\n');
fprintf(fid,'     conductor_N "4_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-4_WPALxx4_WPAL";\n');
fprintf(fid,'     conductor_A "4_WPAL";\n');
fprintf(fid,'     conductor_N "4_WPAL";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-4_WPAL4_WPAL4_WPAL4_WPAL";\n');
fprintf(fid,'     conductor_A "4_WPAL";\n');
fprintf(fid,'     conductor_B "4_WPAL";\n');
fprintf(fid,'     conductor_C "4_WPAL";\n');
fprintf(fid,'     conductor_N "4_WPAL";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-2_ACSR2_ACSR2_ACSR2_ACSR";\n');
fprintf(fid,'     conductor_A "2_ACSR";\n');
fprintf(fid,'     conductor_B "2_ACSR";\n');
fprintf(fid,'     conductor_C "2_ACSR";\n');
fprintf(fid,'     conductor_N "2_ACSR";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-4_ACSRxx1/0_TPX";\n');
fprintf(fid,'     conductor_A "4_ACSR";\n');
fprintf(fid,'     conductor_N "1/0_TPX";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-4_ACSR2_ACSR2_ACSR4_ACSR";\n');
fprintf(fid,'     conductor_A "4_ACSR";\n');
fprintf(fid,'     conductor_B "2_ACSR";\n');
fprintf(fid,'     conductor_C "2_ACSR";\n');
fprintf(fid,'     conductor_N "4_ACSR";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

%Page 3
fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-xx4_ACSR4_WPAL";\n');
fprintf(fid,'     conductor_C "4_ACSR";\n');
fprintf(fid,'     conductor_N "4_WPAL";\n');
fprintf(fid,'     spacing SinglePhase1C;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-4_ACSRxx2_ACSR";\n');
fprintf(fid,'     conductor_A "4_ACSR";\n');
fprintf(fid,'     conductor_N "2_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x4_WPALx1/0_TPX";\n');
fprintf(fid,'     conductor_B "4_WPAL";\n');
fprintf(fid,'     conductor_N "1/0_TPX";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-xx4_ACSR1/0_ACSR";\n');
fprintf(fid,'     conductor_C "4_ACSR";\n');
fprintf(fid,'     conductor_N "1/0_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1C;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-2_ACSRxx4_WPAL";\n');
fprintf(fid,'     conductor_A "2_ACSR";\n');
fprintf(fid,'     conductor_N "4_WPAL";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-xx2/0_ACSR1/0_TPX";\n');
fprintf(fid,'     conductor_C "2/0_ACSR";\n');
fprintf(fid,'     conductor_N "1/0_TPX";\n');
fprintf(fid,'     spacing SinglePhase1C;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "2PH_H-2_ACSRx2_ACSR2_ACSR";\n');
fprintf(fid,'     conductor_A "2_ACSR";\n');
fprintf(fid,'     conductor_C "2_ACSR";\n');
fprintf(fid,'     conductor_N "2_ACSR";\n');
fprintf(fid,'     spacing TwoPhase1AC;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-2_WPALxx2_WPAL";\n');
fprintf(fid,'     conductor_A "2_WPAL";\n');
fprintf(fid,'     conductor_N "2_WPAL";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-2_ACSRxx4/0_TPX";\n');
fprintf(fid,'     conductor_A "2_ACSR";\n');
fprintf(fid,'     conductor_N "4/0_TPX";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-397_ACSR397_ACSR397_ACSR4_WPAL";\n');
fprintf(fid,'     conductor_A "397_ACSR";\n');
fprintf(fid,'     conductor_B "397_ACSR";\n');
fprintf(fid,'     conductor_C "397_ACSR";\n');
fprintf(fid,'     conductor_N "4_WPAL";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-397_ACSR397_ACSR397_ACSR397_ACSR";\n');
fprintf(fid,'     conductor_A "397_ACSR";\n');
fprintf(fid,'     conductor_B "397_ACSR";\n');
fprintf(fid,'     conductor_C "397_ACSR";\n');
fprintf(fid,'     conductor_N "397_ACSR";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-xx2_ACSR1/0_TPX";\n');
fprintf(fid,'     conductor_C "2_ACSR";\n');
fprintf(fid,'     conductor_N "1/0_TPX";\n');
fprintf(fid,'     spacing SinglePhase1C;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x4_ACSRx2_WPAL";\n');
fprintf(fid,'     conductor_B "4_ACSR";\n');
fprintf(fid,'     conductor_N "2_WPAL";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x4_ACSRx4_DPX";\n');
fprintf(fid,'     conductor_B "4_ACSR";\n');
fprintf(fid,'     conductor_N "4_DPX";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-2_ACSR2_ACSR4_ACSR4_ACSR";\n');
fprintf(fid,'     conductor_A "2_ACSR";\n');
fprintf(fid,'     conductor_B "2_ACSR";\n');
fprintf(fid,'     conductor_C "4_ACSR";\n');
fprintf(fid,'     conductor_N "4_ACSR";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

% Page 4
fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-4_WPALxx1/0_TPX";\n');
fprintf(fid,'     conductor_A "4_WPAL";\n');
fprintf(fid,'     conductor_N "1/0_TPX";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x4_ACSRx1/0_TPX";\n');
fprintf(fid,'     conductor_B "4_ACSR";\n');
fprintf(fid,'     conductor_N "1/0_TPX";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-4_ACSRxx1/0_3W_CS";\n');
fprintf(fid,'     conductor_A "4_ACSR";\n');
fprintf(fid,'     conductor_N "1/0_3W_CS";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x2_ACSRx4_ACSR";\n');
fprintf(fid,'     conductor_B "2_ACSR";\n');
fprintf(fid,'     conductor_N "4_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x2_ACSRx1/0_3W_CS";\n');
fprintf(fid,'     conductor_B "2_ACSR";\n');
fprintf(fid,'     conductor_N "1/0_3W_CS";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-2/0_ACSR2/0_ACSR2/0_ACSR2/0_ACSR";\n');
fprintf(fid,'     conductor_A "2/0_ACSR";\n');
fprintf(fid,'     conductor_B "2/0_ACSR";\n');
fprintf(fid,'     conductor_C "2/0_ACSR";\n');
fprintf(fid,'     conductor_N "2/0_ACSR";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-2_ACSRxx1/0_TPX";\n');
fprintf(fid,'     conductor_A "2_ACSR";\n');
fprintf(fid,'     conductor_N "1/0_TPX";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-4_WPAL4_WPAL4_WPAL1/0_TPX";\n');
fprintf(fid,'     conductor_A "4_WPAL";\n');
fprintf(fid,'     conductor_B "4_WPAL";\n');
fprintf(fid,'     conductor_C "4_WPAL";\n');
fprintf(fid,'     conductor_N "1/0_TPX";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x4_WPALx2_ACSR";\n');
fprintf(fid,'     conductor_B "4_WPAL";\n');
fprintf(fid,'     conductor_N "2_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-2/0_ACSR2/0_ACSR2/0_ACSR2_WPAL";\n');
fprintf(fid,'     conductor_A "2/0_ACSR";\n');
fprintf(fid,'     conductor_B "2/0_ACSR";\n');
fprintf(fid,'     conductor_C "2/0_ACSR";\n');
fprintf(fid,'     conductor_N "2_WPAL";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-xx4_ACSR2_ACSR";\n');
fprintf(fid,'     conductor_C "4_ACSR";\n');
fprintf(fid,'     conductor_N "2_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1C;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x4_ACSRx4_TPX";\n');
fprintf(fid,'     conductor_B "4_ACSR";\n');
fprintf(fid,'     conductor_N "4_TPX";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-4_ACSR4_ACSR4_ACSR4_TPX";\n');
fprintf(fid,'     conductor_A "4_ACSR";\n');
fprintf(fid,'     conductor_B "4_ACSR";\n');
fprintf(fid,'     conductor_C "4_ACSR";\n');
fprintf(fid,'     conductor_N "4_TPX";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-4_ACSRxx6_WPAL";\n');
fprintf(fid,'     conductor_A "4_ACSR";\n');
fprintf(fid,'     conductor_N "6_WPAL";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-xx4_ACSR4_TPX";\n');
fprintf(fid,'     conductor_C "4_ACSR";\n');
fprintf(fid,'     conductor_N "4_TPX";\n');
fprintf(fid,'     spacing SinglePhase1C;\n');
fprintf(fid,'}\n\n');

% Page 5
fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-397_ACSR397_ACSR397_ACSR2/0_WPAL";\n');
fprintf(fid,'     conductor_A "397_ACSR";\n');
fprintf(fid,'     conductor_B "397_ACSR";\n');
fprintf(fid,'     conductor_C "397_ACSR";\n');
fprintf(fid,'     conductor_N "2/0_WPAL";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-2/0_ACSRxx2_ACSR";\n');
fprintf(fid,'     conductor_A "2/0_ACSR";\n');
fprintf(fid,'     conductor_N "2_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-2/0_ACSR2/0_ACSR2/0_ACSR4_ACSR";\n');
fprintf(fid,'     conductor_A "2/0_ACSR";\n');
fprintf(fid,'     conductor_B "2/0_ACSR";\n');
fprintf(fid,'     conductor_C "2/0_ACSR";\n');
fprintf(fid,'     conductor_N "4_ACSR";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-xx4_WPAL1/0_TPX";\n');
fprintf(fid,'     conductor_C "4_WPAL";\n');
fprintf(fid,'     conductor_N "1/0_TPX";\n');
fprintf(fid,'     spacing SinglePhase1C;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-xx6_WPAL6_WPAL";\n');
fprintf(fid,'     conductor_C "6_WPAL";\n');
fprintf(fid,'     conductor_N "6_WPAL";\n');
fprintf(fid,'     spacing SinglePhase1C;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x2_ACSRx4_TPX";\n');
fprintf(fid,'     conductor_B "2_ACSR";\n');
fprintf(fid,'     conductor_N "4_TPX";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH_H-4_ACSR4_ACSR4_ACSR2_WPAL";\n');
fprintf(fid,'     conductor_A "4_ACSR";\n');
fprintf(fid,'     conductor_B "4_ACSR";\n');
fprintf(fid,'     conductor_C "4_ACSR";\n');
fprintf(fid,'     conductor_N "2_WPAL";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-x4_ACSRx1/0_3W_CS";\n');
fprintf(fid,'     conductor_B "4_ACSR";\n');
fprintf(fid,'     conductor_N "1/0_3W_CS";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1PH-xx2_ACSR4_DPX";\n');
fprintf(fid,'     conductor_C "2_ACSR";\n');
fprintf(fid,'     conductor_N "4_DPX";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3P_1/0_AXNJ_DB";\n');
fprintf(fid,'     conductor_A "1/0_ACSR"; //These are not the correct values,\n'); 
fprintf(fid,'     conductor_B "1/0_ACSR"; //but are used to approximate for 3P & 1P.\n'); 
fprintf(fid,'     conductor_C "1/0_ACSR";\n'); 
fprintf(fid,'     conductor_N "1/0_ACSR";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1P_1/0_AXNJ_DB_A";\n');
fprintf(fid,'     conductor_A "1/0_ACSR";\n');
fprintf(fid,'     conductor_N "1/0_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1P_1/0_AXNJ_DB_B";\n');
fprintf(fid,'     conductor_B "1/0_ACSR";\n');
fprintf(fid,'     conductor_N "1/0_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1B;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "1P_1/0_AXNJ_DB_C";\n');
fprintf(fid,'     conductor_C "1/0_ACSR";\n');
fprintf(fid,'     conductor_N "1/0_ACSR";\n');
fprintf(fid,'     spacing SinglePhase1C;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "CAP_LINE";      //Also known as 1PH-Connector.\n');
fprintf(fid,'     conductor_A "600_CU"; //These are not the correct values, but\n');
fprintf(fid,'     conductor_B "600_CU"; //will be used to approx. low loss lines.\n');
fprintf(fid,'     conductor_C "600_CU";\n');
fprintf(fid,'     conductor_N "600_CU";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object line_configuration {\n');
fprintf(fid,'     name "3PH-Connector";\n');
fprintf(fid,'     conductor_A "600_CU";\n');
fprintf(fid,'     conductor_B "600_CU";\n');
fprintf(fid,'     conductor_C "600_CU";\n');
fprintf(fid,'     conductor_N "600_CU";\n');
fprintf(fid,'     spacing ThreePhase1;\n');
fprintf(fid,'}\n\n');

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Create Triplex Line and Conductor Configurations
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf(fid,'object triplex_line_conductor {\n');
fprintf(fid,'     name "4/0triplex";\n');
fprintf(fid,'     resistance 1.535;\n');
fprintf(fid,'     geometric_mean_radius 0.0111;\n');
fprintf(fid,'     rating.summer.emergency 315 A;\n');
fprintf(fid,'     rating.summer.continuous 315 A;\n');
fprintf(fid,'     rating.winter.emergency 315 A;\n');
fprintf(fid,'     rating.winter.continuous 315 A;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object triplex_line_configuration {\n');
fprintf(fid,'     name "4/0Triplex";\n');
fprintf(fid,'     conductor_1 "4/0triplex";\n'); 
fprintf(fid,'     conductor_2 "4/0triplex";\n');
fprintf(fid,'     conductor_N "4/0triplex";\n');
fprintf(fid,'     insulation_thickness 0.08;\n');
fprintf(fid,'     diameter 0.368;\n');
fprintf(fid,'}\n\n');

fprintf(fid,'object triplex_line_configuration {\n');
fprintf(fid,'     name "750_Triplex";       //These values are not correct, but\n');
fprintf(fid,'     conductor_1 "4/0triplex"; //there are only four of them.\n');
fprintf(fid,'     conductor_2 "4/0triplex";\n');
fprintf(fid,'     conductor_N "4/0triplex";\n');
fprintf(fid,'     insulation_thickness 0.08;\n');
fprintf(fid,'     diameter 0.368;\n');
fprintf(fid,'}\n\n');


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Create line objects
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf(fid,'// Overhead Lines\n\n');

for i=1:EndLines
    if (~isempty(findstr(char(RawLines{1}(i)),'CAP')))
        % if it's a capacitor line don't create a line - 
        %  create capacitor lines by hand to combine the three phasees
    elseif (~isempty(findstr(char(RawLines{1}(i)),'_sw')))
        %switches
        if (~isempty(findstr(char(RawLines{1}(i)),'WF586_48332_sw')) || ~isempty(findstr(char(RawLines{1}(i)),'V7995_48332_sw')) || ~isempty(findstr(char(RawLines{1}(i)),'WD701_48332_sw')))
            % do nothing - these are open switches connecting two different
            % phases - doesn't work in NR right now
        else
            fprintf(fid,'object switch {\n');
            fprintf(fid,'     phases %sN;\n',char(RawLines{3}(i)));
            fprintf(fid,'     name "%s";\n',char(RawLines{1}(i)));
            fprintf(fid,'     from "%s";\n',char(RawLines{2}(i)));
            fprintf(fid,'     to "%s";\n',char(RawLines{4}(i)));
            status = strtrim(char(RawLines{9}(i)));
            if (~isempty(findstr(status,'open')))
                fprintf(fid,'     status OPEN;\n');
            else
                fprintf(fid,'     status CLOSED;\n');
            end
            fprintf(fid,'}\n\n');
        end
    elseif (~isempty(findstr(char(RawLines{8}(i)),'1P_1/0_AXNJ_DB')))
        fprintf(fid,'object overhead_line {\n');
        fprintf(fid,'     phases %sN;\n',char(RawLines{3}(i))); 
        fprintf(fid,'     name "%s";\n',char(RawLines{1}(i)));
        fprintf(fid,'     from "%s";\n',char(RawLines{2}(i)));
        fprintf(fid,'     to "%s";\n',char(RawLines{4}(i)));
        fprintf(fid,'     length %f%s;\n',LengthLines(i),char(RawLines{7}(i)));
        k = strtrim(char(RawLines{8}(i)));
        fprintf(fid,'     configuration "%s_%s";\n',k,char(RawLines{3}(i)));
        fprintf(fid,'}\n\n');
    else
        % normal lines
        fprintf(fid,'object overhead_line {\n');
        fprintf(fid,'     phases %sN;\n',char(RawLines{3}(i)));
        % one odd ball line had a node name, so add LN to it
        if (strcmp(char(RawLines{1}(i)),'293471'))
            fprintf(fid,'     name "LN%s";\n',char(RawLines{1}(i)));
        else
            fprintf(fid,'     name "%s";\n',char(RawLines{1}(i)));
        end
        fprintf(fid,'     from "%s";\n',char(RawLines{2}(i)));
        fprintf(fid,'     to "%s";\n',char(RawLines{4}(i)));
        fprintf(fid,'     length %f%s;\n',LengthLines(i),char(RawLines{7}(i)));
          k = strtrim(char(RawLines{8}(i)));
        fprintf(fid,'     configuration "%s";\n',k);
        fprintf(fid,'}\n\n');
        
    end
end



fclose('all');
disp('File generation completed.');
