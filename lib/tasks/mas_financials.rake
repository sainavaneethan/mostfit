require "rubygems"

# Add the local gems dir if found within the app root; any dependencies loaded
# hereafter will try to load from the local gems before loading system gems.
if (local_gem_dir = File.join(File.dirname(__FILE__), '..', '..', 'gems')) && $BUNDLE.nil?
  $BUNDLE = true; Gem.clear_paths; Gem.path.unshift(local_gem_dir)
end

require "merb-core"

# this loads all plugins required in your init file so don't add them
# here again, Merb will do it for you
Merb.start_environment(:environment => ENV['MERB_ENV'] || 'development')

namespace :mostfit do
  desc "Generates report of MAS financials for Intellecash"
  task :mas_financials do

    client_ids = [15567,15568,15540,15569,15570,15571,6153,6132,6133,6156,6145,6136,6151,6148,6141,15572,15573,15574,15575,15576,15588,15589,15590,15591,15592,4814,4805,15666,4830,15593,4816,4811,15594,5428,15595,15596,4812,15667,15597,4831,5989,6492,5986,6491,6502,5991,6480,6482,5993,6485,15539,5984,5981,6496,6507,5994,6489,6483,5985,6477,6487,5992,6505,5995,6498,6500,5983,5988,5990,5987,6004,15646,6011,15655,5999,15656,6015,15658,6001,15660,6007,6012,6006,15662,6009,15648,15650,6013,15652,6014,15653,6008,5998,6580,6010,6584,6574,5997,6575,6582,6577,6356,6355,6573,6358,6357,6583,6359,15559,6874,6360,15560,6361,6869,6362,6870,6363,6872,6364,15561,6368,6367,6369,15553,5693,15554,6033,5697,5696,6027,5695,6029,15508,6053,5959,6055,6032,6057,6049,6022,15607,6619,15641,15644,6617,15637,15639,6615,6620,6613,6332,6330,6320,5343,6319,5345,6318,15609,6321,6322,15493,15494,15495,15496,15497,15499,15501,15505,15506,15507,15636,15638,15640,15642,15643,15647,15649,15651,15654,15657,15659,15661,15663,15664,15665,15587,15598,15599,15600,15601,15602,15603,15604,15605,15606,15626,15627,15628,15629,15630,15631,15632,15633,15634,15635,15608,15612,15613,15614,15615,15616,15617,15618,15619,15620,15621,15622,15623,15624,15625,15511,15512,15515,15518,15523,5439,5431,5442,5438,15645,15678,15709,15710,15711,15712,15713,15714,15715,15716,15717,15668,15669,15670,15671,15672,15673,15674,15675,15676,15677,15679,15680,15681,15682,15683,15684,15685,15686,15687,15688,15689,15690,15691,15692,15693,15694,15695,15696,15697,15698,15699,15700,15701,15702,15703,15704,15705,15706,15707,15708,15759,15755,15753,15750,15748,5485,5486,5484,15611,15610,15764,6524,5932,15769,6527,5924,5926,15768,5920,6522,5934,6512,6514,5918,6517,5923,6531,5925,5922,15775,6060,3697,5579,6072,5415,6074,5418,6062,6058,15733,15718,15736,15719,15720,15721,15724,15725,6241,15728,6244,15730,6247,15731,6246,15732,6242,15735,15737,15738,15740,5750,5752,6236,6234,6238,7522,6231,6232,6230,7523,15729,5748,15734,15726,15727,15558,6002,6000,6003,5996,6590,6599,6431,6595,6430,6597,6434,6594,6432,6593,15770,15773,15771,15772,6592,3512,5190,6226,7041,5189,6224,7056,6223,7051,5192,7043,7046,5188,6227,15776,5183,5187,15778,15781,7048,15782,15779,15749,15780,15783,15751,15784,15756,6807,15752,6802,15758,6809,6800,5796,7035,15739,5792,15741,5794,4925,15742,5797,15743,5795,7036,15744,4920,6804,7038,15562,15563,2055,15564,15565,4016,4018,15566,15754,15757,14839,15850,15855,15857,15859,15803,15805,15806,15807,15808,15809,15810,15811,15812,15814,15819,15828,15830,15832,15833,15835,15837,15838,15841,15846,15760,15763,15765,15767,15774,15777,15785,15786,15787,15788,15789,15790,15798,15800,15801,15745,15746,15747,15816,15820,15821,15823,15824,15825,15826,15829,15840,15844,15847,15848,15577,15578,15579,15580,15581,15582,15583,15584,15585,15586,15827,15831,15834,15836,15839,15842,15843,15845,15849,15851,15852,15853,15854,15856,15858,6550,6549,6554,15761,15762,15867,15868,15869,15870,15871,6936,6931,6933,6935,6941,6939,6112,6932,15877,6930,15878,15860,15879,15861,15880,15862,15872,15873,15863,15874,15864,15875,15876,15865,15866,5865,6632,6610,5857,6618,15815,5867,6621,5859,6628,5860,5861,6633,5862,6612,15817,15813,6626,5871,5870,6616,5872,6630,5868,5869,15818,5864,15822,5866,6634,15896,15898,15899,15900,5884,15902,5883,15905,5880,15906,15897,15907,5888,15910,5878,15912,5877,5876,5873,5875,5879,5881,5874,5887,5886,15966,15969,15973,15975,15980,15984,15986,15988,15990,15991,15925,15926,15927,15928,15929,15931,15933,15936,15938,15939,15940,15941,15954,15957,15960,15901,15903,15909,15911,15913,15914,15915,15916,15918,15919,15920,15921,15922,15923,15924,15881,15882,15883,15884,15885,15886,15887,15888,15889,15890,15891,15892,15893,15894,15895,5466,5464,5477,5469,15930,15932,5468,5470,15934,5472,5465,5475,15935,5463,15937,15904,6034,6038,15995,6035,15997,15908,6045,6044,6043,6040,6042,15992,6024,15917,6028,6031,6026,16007,16009,16011,16013,6720,15999,6589,16001,16003,6585,6587,15961,5785,15962,6586,15965,16017,16016,5786,15968,5783,15971,6588,15976,15979,16018,15982,15985,16019,3500,15950,15989,16020,15952,15955,16021,15959,7090,7089,7084,7086,6277,15944,15993,6273,6279,15994,6284,6289,6283,15722,15996,15723,15998,2390,2385,2386,15963,15964,15967,15970,15972,15974,15977,16037,16038,15978,16039,15983,15987,16045,16040,16000,16002,16004,16005,16008,16010,16012,16014,16015,16006,16063,16068,16073,16074,16076,16041,16077,16078,16079,16081,16042,16085,16044,16047,16048,16051,16053,16055,16057,16060,16093,16095,16022,16023,16024,16025,16026,16027,16028,16029,16030,16031,16032,16033,16034,16035,16036,16103,16107,16043,16110,16046,16117,16050,16118,16121,16052,16054,16124,16056,16127,16058,16059,16061,16064,16062,16065,16067,16066,16069,16070,16071,16092,16072,16075,16105,16106,16109,16114,16115,16119,16123,16125,16126,16128,16129,16130,16080,16082,16131,16083,16084,16086,16132,16087,16133,16088,16089,16090,16091,16094,16096,16097,16098,16099,16100,6155,16101,16102,16104,16108,16111,16112,6149,16113,16116,6140,16120,16122,6146,6152,6135,16134,6144,6143,6150,16135,6154,6138,6134,6147,15791,15792,15793,15794,15795,15796,15797,15799,15802,15804,16141,16142,16143,16144,16145,5939,5941,6661,5946,6658,6660,5943,6657,16148,16136,5948,5453,5949,5450,5451,5952,16146,16137,6323,16147,6327,5954,5953,16150,5957,16151,16138,16149,16139,16140,16152,16153,16154,16155,16160,16159,16158,16157,16156,16175,16176,16178,16180,16182,16161,16162,16163,16165,16166,16168,16169,16170,16172,16173,16177,16179,16181,16183,16184,16185,16186,16187,16189,16190,16191,16192,16194,16195,16196,16198,16199,16200,16201,16204,16209,16211,16213,16214,16215,16188,16193,16197,16205,16207,16210,16212,16216,16219,16224,16225,16227,16229,16232,16233,16217,16218,16220,16221,16222,16223,16226,16228,16230,16231,5940,16234,16164,16167,16171,16174,16235,16236,16237,5180,16238,16202,16239,16203,16240,16241,16206,16243,16208,16245,16242,16244,16246,16247,16248]

    loan_ids = [19246,19247,19248,19249,19250,19251,19252,19253,19254,19255,19256,19257,19258,19259,19260,19261,19262,19263,19264,19265,19267,19268,19269,19270,19271,19272,19273,19274,19275,19276,19277,19278,19279,19280,19281,19282,19283,19284,19285,19286,19287,19288,19289,19290,19291,19292,19293,19294,19295,19296,19297,19298,19299,19300,19301,19302,19303,19304,19305,19306,19307,19308,19309,19310,19311,19312,19313,19314,19315,19316,19317,19318,19319,19320,19321,19322,19323,19324,19325,19326,19327,19328,19329,19330,19331,19332,19333,19334,19335,19336,19337,19338,19339,19340,19341,19342,19343,19344,19345,19346,19347,19348,19349,19350,19351,19352,19353,19354,19355,19356,19357,19358,19359,19360,19361,19362,19363,19364,19365,19366,19367,19368,19369,19370,19371,19372,19373,19374,19375,19376,19377,19378,19379,19380,19381,19382,19383,19384,19385,19386,19388,19389,19390,19391,19392,19393,19394,19395,19396,19397,19398,19399,19400,19401,19402,19403,19404,19405,19406,19407,19408,19409,19410,19411,19412,19413,19414,19415,19416,19417,19418,19419,19420,19421,19422,19423,19424,19425,19426,19427,19428,19429,19430,19431,19432,19433,19434,19435,19436,19437,19438,19439,19440,19441,19442,19443,19444,19445,19446,19447,19448,19449,19450,19451,19452,19453,19454,19455,19456,19457,19458,19459,19460,19461,19462,19463,19464,19465,19466,19467,19468,19469,19470,19471,19472,19473,19474,19475,19476,19477,19478,19479,19480,19481,19482,19483,19484,19485,19486,19487,19488,19489,19490,19491,19492,19493,19494,19495,19496,19497,19498,19499,19500,19501,19502,19503,19504,19505,19506,19507,19508,19509,19510,19511,19512,19513,19514,19515,19516,19517,19518,19519,19520,19521,19522,19523,19524,19525,19526,19527,19528,19529,19530,19531,19532,19533,19534,19535,19536,19537,19538,19539,19540,19541,19542,19543,19544,19545,19546,19547,19548,19549,19550,19551,19552,19553,19554,19555,19556,19557,19558,19559,19560,19561,19562,19563,19564,19565,19566,19567,19568,19569,19570,19571,19572,19573,19574,19575,19576,19577,19578,19579,19580,19581,19582,19583,19584,19585,19586,19587,19588,19589,19590,19591,19592,19593,19594,19595,19596,19597,19598,19599,19600,19601,19602,19603,19604,19605,19606,19607,19608,19609,19610,19611,19612,19613,19614,19615,19616,19617,19618,19619,19620,19621,19622,19623,19624,19625,19626,19627,19628,19629,19630,19631,19632,19633,19634,19635,19636,19637,19638,19639,19640,19641,19642,19643,19644,19645,19646,19647,19648,19649,19650,19651,19652,19653,19654,19655,19656,19657,19658,19659,19660,19661,19662,19663,19664,19665,19666,19667,19668,19669,19670,19671,19672,19673,19674,19675,19676,19677,19678,19679,19680,19681,19682,19683,19684,19685,19686,19687,19688,19689,19690,19691,19692,19693,19694,19695,19696,19697,19698,19699,19700,19701,19702,19704,19705,19706,19707,19708,19709,19710,19711,19712,19713,19714,19715,19716,19717,19718,19719,19720,19721,19722,19723,19724,19725,19726,19727,19728,19729,19730,19731,19732,19733,19734,19735,19736,19737,19738,19739,19740,19741,19742,19743,19744,19745,19746,19747,19748,19749,19750,19751,19752,19753,19754,19755,19756,19757,19758,19759,19760,19761,19762,19763,19764,19765,19766,19767,19768,19769,19770,19771,19772,19773,19774,19775,19776,19777,19778,19779,19780,19781,19782,19783,19784,19785,19786,19787,19788,19789,19790,19791,19792,19793,19794,19795,19796,19797,19798,19799,19800,19801,19802,19803,19804,19805,19806,19807,19808,19809,19810,19811,19812,19813,19814,19815,19816,19817,19818,19819,19820,19821,19822,19823,19824,19825,19826,19827,19828,19829,19830,19831,19832,19833,19834,19835,19837,19838,19839,19840,19841,19842,19843,19844,19845,19846,19847,19848,19849,19850,19851,19852,19853,19854,19855,19856,19857,19858,19859,19860,19861,19862,19863,19864,19865,19866,19867,19868,19869,19870,19871,19872,19873,19874,19875,19876,19877,19878,19879,19880,19881,19882,19883,19884,19885,19886,19887,19888,19889,19890,19891,19892,19893,19894,19895,19896,19897,19898,19899,19900,19901,19902,19903,19904,19905,19906,19907,19908,19909,19910,19911,19912,19913,19915,19916,19917,19918,19919,19920,19921,19922,19923,19924,19925,19926,19927,19928,19930,19931,19932,19933,19934,19935,19936,19937,19938,19939,19940,19941,19942,19943,19944,19945,19946,19947,19948,19949,19950,19951,19952,19953,19954,19955,19956,19957,19958,19959,19960,19961,19962,19963,19964,19965,19966,19967,19968,19969,19970,19971,19972,19973,19974,19975,19976,19977,19978,19979,19980,19981,19982,19983,19984,19985,19986,19987,19988,19989,19990,19991,19992,19993,19994,19995,19996,19997,19998,19999,20000,20001,20002,20003,20004,20005,20006,20007,20008,20009,20010,20011,20012,20013,20014,20015,20016,20017,20018,20019,20020,20021,20022,20023,20024,20025,20026,20027,20028,20029,20030,20031,20032,20033,20034,20035,20036,20037,20038,20039,20040,20041,20042,20043,20044,20045,20046,20047,20048,20049,20050,20051,20052,20053,20054,20055,20056,20057,20058,20059,20060,20061,20062,20063,20064,20065,20066,20067,20068,20069,20070,20071,20072,20073,20074,20075,20076,20077,20078,20079,20080,20081,20082,20083,20084,20085,20086,20087,20088,20089,20090,20091,20092,20093,20094,20095,20096,20097,20098,20099,20100,20101,20102,20103,20104,20105,20106,20107,20108,20109,20110,20111,20112,20113,20114,20115,20116,20117,20118,20119,20120,20121,20122,20123,20124,20125,20126,20127,20128,20129,20130,20131,20132,20133,20134,20135,20136,20137,20138,20139,20140,20141,20142,20143,20144,20145,20146,20147,20148,20149,20150,20151,20152,20153,20154,20155,20156,20157,20159,20160,20161,20162,20163,20164,20165,20166,20167,20168,20169,20170,20171,20172,20173,20174,20175,20176,20177,20178,20179,20180,20181,20182,20183,20184,20185,20186,20187,20188,20189,20190,20191,20192,20193,20194,20195,20196,20197,20198,20199,20200,20201,20202,20203,20204,20205,20206,20207,20208,20209,20210,20211,20212,20213,20214,20215,20216,20217,20218,20219,20220,20221,20222,20223,20224,20225,20226,20227,20228,20229,20230,20231,20232,20233,20234,20235,20236,20237,20238,20239,20240,20241,20242,20243,20244,20245,20246,20247,20248,20249,20250,20251,20252,20253,20254,20255,20256,20257,20258,20259,20260,20261,20262,20263,20264,20265,20266,20267,20268,20269,20270,20271,20272,20273,20274,20275,20276,20277,20278,20279,20280,20281,20282,20283,20284,20285,20286,20287,20288,20289,20290,20291,20292]

    disbursal_dates = [Date.new(2012, 03, 22), Date.new(2012, 03, 23), Date.new(2012, 03, 26), Date.new(2012, 03, 27), Date.new(2012, 03, 28), Date.new(2012, 03, 29), Date.new(2012, 03, 30)]

    date = Date.new(2012, 03, 31)

    #following are the various dates on which monthly cash flows is being calculated.
    from_dates = [Date.new(2012, 03, 01), Date.new(2012, 04, 01), Date.new(2012, 05, 01), Date.new(2012, 06, 01), Date.new(2012, 07, 01), Date.new(2012, 8, 01), Date.new(2012, 9, 01), Date.new(2012, 10, 01), Date.new(2012, 11, 01), Date.new(2012, 12, 01), Date.new(2013, 01, 01), Date.new(2013, 02, 01), Date.new(2013, 03, 01), Date.new(2013, 04, 01), Date.new(2013, 05, 01), Date.new(2013, 06, 01), Date.new(2013, 07, 01), Date.new(2013, 8, 01), Date.new(2013, 9, 01), Date.new(2013, 10, 01), Date.new(2013, 11, 01), Date.new(2013, 12, 01), Date.new(2014, 01, 01), Date.new(2014, 02, 01), Date.new(2014, 03, 01), Date.new(2014, 04, 01), Date.new(2014, 05, 01), Date.new(2014, 06, 01), Date.new(2014, 07, 01), Date.new(2014, 8, 01)]

    to_dates = [Date.new(2012, 03, 31), Date.new(2012, 04, 30), Date.new(2012, 05, 31), Date.new(2012, 06, 30), Date.new(2012, 07, 31), Date.new(2012, 8, 31), Date.new(2012, 9, 30), Date.new(2012, 10, 31), Date.new(2012, 11, 30), Date.new(2012, 12, 31), Date.new(2013, 01, 31), Date.new(2013, 02, 28), Date.new(2013, 03, 31), Date.new(2013, 04, 30), Date.new(2013, 05, 31), Date.new(2013, 06, 30), Date.new(2013, 07, 31), Date.new(2013, 8, 31), Date.new(2013, 9, 30), Date.new(2013, 10, 31), Date.new(2013, 11, 30), Date.new(2013, 12, 31), Date.new(2014, 01, 01), Date.new(2014, 02, 28), Date.new(2014, 03, 31), Date.new(2014, 04, 30), Date.new(2014, 05, 31), Date.new(2014, 06, 30), Date.new(2014, 07, 31), Date.new(2014, 8, 31)]

    sl_no = 0

    f = File.open("tmp/mas_financials_#{DateTime.now.to_s}.csv", "w")
    f.puts("\"Sl. No.\", \"Branch Id\", \"Branch Name\", \"Center Id\", \"Center Name\", \"Client Id\", \"Client Name\", \"Date of Birth\", \"Caste\", \"Residence Address\", \"Residence Pin Code\", \"State\", \"Residence Phone Number\", \"Name of Assets\", \"Gross Income\", \"Gender\", \"Name of Marketing Executive\", \"Loan Id\", \"Purpose of Loans\", \"Category of Loanee\", \"Cycle Number\", \"Date of Disbursement\", \"Disbursement Mode\", \"Disbursement Cheque Number\", \"First Installment Date\", \"Last Installment Date\", \"Scheme IRR (%)\", \"Amount Financed\", \"Upfront Fees Amount in Rs.\", \"Insurance Charges\", \"Any Other Charges\", \"Installment Amount\", \"Tenure in Weeks\", \"Advance EMI\", \"No. Of Installment\", \"EMI Frequency\", \"Seasoning\", \"OD. Inst.\", \"Od. Amt. Rs.\", \"SD Amt. Rs.\", \"SD. Refund / Scheme Refund\", \"Mode of Repayment\", \"KYC Detail\", \"Future Capital O/S Amt. Rs.\", \"Future O/S Installment\", \"Future Receivable Amt. Rs.\", \"Cash Flow in March 2012\", \"Cash Flow in April 2012\", \"Cash Flow in May 2012\", \"Cash Flow in June 2012\", \"Cash Flow in July 2012\", \"Cash Flow in August 2012\", Cash Flow in September 2012, \"Cash Flow in October 2012\", \"Cash Flow in November 2012\", \"Cash Flow in December 2012\", \"Cash Flow in January 2013\", \"Cash Flow in February 2013\", \"Cash Flow in March 2013\", \"Cash Flow in April 2013\", \"Cash Flow in May 2013\", \"Cash Flow in June 2013\", \"Cash Flow in July 2013\", \"Cash Flow in August 2013\", \"Cash Flow in September 2013\", \"Cash Flow in October 2013\", \"Cash Flow in November 2013\", \"Cash Flow in December 2013\", \"Cash Flow in January 2014\", \"Cash Flow in February 2014\", \"Cash Flow in March 2014\", \"Cash Flow in April 2014\", \"Cash Flow in May 2014\", \"Cash Flow in June 2014\", \"Cash Flow in July 2014\", \"Cash Flow in August 2014\"")

    Loan.all(:id => loan_ids, :client_id => client_ids, :disbursal_date => disbursal_dates).each do |loan|

      sl_no += 1

      client = Client.get(loan.client_id)
      client_id = client.id
      client_name = client.name
      client_date_of_birth = client.date_of_birth
      client_caste = client.caste
      client_address = ""
      client_address_pin_code = client.address_pin
      client_state = "Bihar"
      if client.phone_number
        client_phone_number = client.phone_number
      else
        client_phone_number = "Not Specified"
      end
      client_name_of_assets = "NA"
      client_gross_income = client.total_income
      client_gender = client.gender.capitalize
      client_marketing_executive = client.center.manager.name

      center_id = client.center.id
      center_name = client.center.name

      branch_id = client.center.branch.id
      branch_name = client.center.branch.name

      loan_id = loan.id
      loan_cycle_number = loan.cycle_number
      loan_category = "NA"
      loan_purpose = (loan.occupation ? loan.occupation.name : "Not specified")
      loan_disbursal_date = loan.disbursal_date
      if loan.cheque_number.empty?
        loan_disbursement_mode = "Cash"
        loan_disbursement_cheque_number = "NA"
      else
        loan_disbursement_mode = "Cheque"
        loan_disbursement_cheque_number = loan.cheque_number
      end
      loan_first_installment_date = loan.scheduled_first_payment_date
      loan_last_installment_date = loan.loan_history.max(:date, :conditions => ['principal_due_today != ?', 0.0], :conditions => ['interest_due_today != ?', 0.0])
      loan_scheme_irr = (loan.irr * 100)
      loan_product_name = loan.loan_product.name
      loan_amount_financed = loan.amount
      loan_upfront_fees = loan.applicable_fees[0].amount
      loan_insurance_charges = loan.applicable_fees[1].amount
      loan_any_other_charges = "NA"
      loan_installment_amount = (loan.scheduled_principal_for_installment(1) + loan.scheduled_interest_for_installment(1))
      loan_tenure = loan.number_of_installments
      loan_advance_emi = ""
      loan_number_of_installments = loan.number_of_installments
      loan_installment_frequency = loan.installment_frequency.to_s.capitalize
      loan_seasoning = "NA"
      loan_overdue_installment = 0
      loan_overdue_amount = 0
      loan_sd_amount = "NA"
      loan_sd_refund = "NA"
      loan_mode_of_repayment = "Cash"
      loan_kyc_details = "Yes"
      loan_future_outstanding_amount = loan.scheduled_outstanding_total_on(date)
      loan_future_outstanding_installment = (loan.number_of_installments - loan.number_of_installments_before(date))
      loan_future_receivable_amount = (loan.total_to_be_received - loan.total_received_up_to(date))

      if (loan.scheduled_first_payment_date >= from_dates[0] and loan.scheduled_first_payment_date <= to_dates[0])
        monthly_cash_flow_march_2012 = (loan.scheduled_principal_for_installment(1) + loan.scheduled_interest_for_installment(1))
      else
        monthly_cash_flow_march_2012 = 0
      end
      monthly_cash_flow_april_2012 = (loan.scheduled_outstanding_total_on(from_dates[1]) - loan.scheduled_outstanding_total_on(to_dates[1]))
      monthly_cash_flow_may_2012 = (loan.scheduled_outstanding_total_on(from_dates[2]) - loan.scheduled_outstanding_total_on(to_dates[2]))
      monthly_cash_flow_june_2012 = (loan.scheduled_outstanding_total_on(from_dates[3]) - loan.scheduled_outstanding_total_on(to_dates[3]))
      monthly_cash_flow_july_2012 = (loan.scheduled_outstanding_total_on(from_dates[4]) - loan.scheduled_outstanding_total_on(to_dates[4]))
      monthly_cash_flow_august_2012 = (loan.scheduled_outstanding_total_on(from_dates[5]) - loan.scheduled_outstanding_total_on(to_dates[5]))
      monthly_cash_flow_september_2012 = (loan.scheduled_outstanding_total_on(from_dates[6]) - loan.scheduled_outstanding_total_on(to_dates[6]))
      monthly_cash_flow_october_2012 = (loan.scheduled_outstanding_total_on(from_dates[7]) - loan.scheduled_outstanding_total_on(to_dates[7]))
      monthly_cash_flow_november_2012 = (loan.scheduled_outstanding_total_on(from_dates[8]) - loan.scheduled_outstanding_total_on(to_dates[8]))
      monthly_cash_flow_december_2012 = (loan.scheduled_outstanding_total_on(from_dates[9]) - loan.scheduled_outstanding_total_on(to_dates[9]))

      monthly_cash_flow_january_2013 = (loan.scheduled_outstanding_total_on(from_dates[10]) - loan.scheduled_outstanding_total_on(to_dates[10]))
      monthly_cash_flow_february_2013 = (loan.scheduled_outstanding_total_on(from_dates[11]) - loan.scheduled_outstanding_total_on(to_dates[11]))
      monthly_cash_flow_march_2013 = (loan.scheduled_outstanding_total_on(from_dates[12]) - loan.scheduled_outstanding_total_on(to_dates[12]))
      monthly_cash_flow_april_2013 = (loan.scheduled_outstanding_total_on(from_dates[13]) - loan.scheduled_outstanding_total_on(to_dates[13]))
      monthly_cash_flow_may_2013 = (loan.scheduled_outstanding_total_on(from_dates[14]) - loan.scheduled_outstanding_total_on(to_dates[14]))
      monthly_cash_flow_june_2013 = (loan.scheduled_outstanding_total_on(from_dates[15]) - loan.scheduled_outstanding_total_on(to_dates[15]))
      monthly_cash_flow_july_2013 = (loan.scheduled_outstanding_total_on(from_dates[16]) - loan.scheduled_outstanding_total_on(to_dates[16]))
      monthly_cash_flow_august_2013 = (loan.scheduled_outstanding_total_on(from_dates[17]) - loan.scheduled_outstanding_total_on(to_dates[17]))
      monthly_cash_flow_september_2013 = (loan.scheduled_outstanding_total_on(from_dates[18]) - loan.scheduled_outstanding_total_on(to_dates[18]))
      monthly_cash_flow_october_2013 = (loan.scheduled_outstanding_total_on(from_dates[19]) - loan.scheduled_outstanding_total_on(to_dates[19]))
      monthly_cash_flow_november_2013 = (loan.scheduled_outstanding_total_on(from_dates[20]) - loan.scheduled_outstanding_total_on(to_dates[20]))
      monthly_cash_flow_december_2013 = (loan.scheduled_outstanding_total_on(from_dates[21]) - loan.scheduled_outstanding_total_on(to_dates[21]))

      monthly_cash_flow_january_2014 = (loan.scheduled_outstanding_total_on(from_dates[22]) - loan.scheduled_outstanding_total_on(to_dates[22]))
      monthly_cash_flow_february_2014 = (loan.scheduled_outstanding_total_on(from_dates[23]) - loan.scheduled_outstanding_total_on(to_dates[23]))
      monthly_cash_flow_march_2014 = (loan.scheduled_outstanding_total_on(from_dates[24]) - loan.scheduled_outstanding_total_on(to_dates[24]))
      monthly_cash_flow_april_2014 = (loan.scheduled_outstanding_total_on(from_dates[25]) - loan.scheduled_outstanding_total_on(to_dates[25]))
      monthly_cash_flow_may_2014 = (loan.scheduled_outstanding_total_on(from_dates[26]) - loan.scheduled_outstanding_total_on(to_dates[26]))
      monthly_cash_flow_june_2014 = (loan.scheduled_outstanding_total_on(from_dates[27]) - loan.scheduled_outstanding_total_on(to_dates[27]))
      monthly_cash_flow_july_2014 = (loan.scheduled_outstanding_total_on(from_dates[28]) - loan.scheduled_outstanding_total_on(to_dates[28]))
      monthly_cash_flow_august_2014 = (loan.scheduled_outstanding_total_on(from_dates[29]) - loan.scheduled_outstanding_total_on(to_dates[29]))
      
      f.puts("#{sl_no}, #{branch_id}, \"#{branch_name}\", #{center_id}, \"#{center_name}\", #{client_id}, \"#{client_name}\", #{client_date_of_birth}, \"#{client_caste}\", \"#{client_address}\", #{client_address_pin_code}, \"#{client_state}\", #{client_phone_number}, \"#{client_name_of_assets}\", #{client_gross_income}, \"#{client_gender}\", \"#{client_marketing_executive}\", #{loan_id}, \"#{loan_purpose}\", \"#{loan_category}\", #{loan_cycle_number}, #{loan_disbursal_date}, \"#{loan_disbursement_mode}\", \"#{loan_disbursement_cheque_number}\", #{loan_first_installment_date}, #{loan_last_installment_date}, \"#{loan_scheme_irr}\", #{loan_amount_financed}, #{loan_upfront_fees}, #{loan_insurance_charges}, #{loan_any_other_charges}, #{loan_installment_amount}, #{loan_tenure}, #{loan_advance_emi}, #{loan_number_of_installments}, \"#{loan_installment_frequency}\", \"#{loan_seasoning}\", #{loan_overdue_installment}, #{loan_overdue_amount}, \"#{loan_sd_amount}\", \"#{loan_sd_refund}\", \"#{loan_mode_of_repayment}\", \"#{loan_kyc_details}\", #{loan_future_outstanding_amount}, #{loan_future_outstanding_installment}, #{loan_future_receivable_amount}, #{monthly_cash_flow_march_2012}, #{monthly_cash_flow_april_2012}, #{monthly_cash_flow_may_2012}, #{monthly_cash_flow_june_2012}, #{monthly_cash_flow_july_2012}, #{monthly_cash_flow_august_2012}, #{monthly_cash_flow_september_2012}, #{monthly_cash_flow_october_2012}, #{monthly_cash_flow_november_2012}, #{monthly_cash_flow_december_2012}, #{monthly_cash_flow_january_2013}, #{monthly_cash_flow_february_2013}, #{monthly_cash_flow_march_2013}, #{monthly_cash_flow_april_2013}, #{monthly_cash_flow_may_2013}, #{monthly_cash_flow_june_2013}, #{monthly_cash_flow_july_2013}, #{monthly_cash_flow_august_2013}, #{monthly_cash_flow_september_2013}, #{monthly_cash_flow_october_2013}, #{monthly_cash_flow_november_2013}, #{monthly_cash_flow_december_2013}, #{monthly_cash_flow_january_2014}, #{monthly_cash_flow_february_2014}, #{monthly_cash_flow_march_2014}, #{monthly_cash_flow_april_2014}, #{monthly_cash_flow_may_2014}, #{monthly_cash_flow_june_2014}, #{monthly_cash_flow_july_2014}, #{monthly_cash_flow_august_2014}")

    end
    f.close
  end
end
