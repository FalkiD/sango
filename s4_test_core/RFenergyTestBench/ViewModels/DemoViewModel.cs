using System;
using System.Linq;
using System.Reactive.Linq;
using BusinessObjects;
using System.Collections.Generic;
using ReactiveUI;
using ReactiveUI.Routing;
using ReactiveUI.Xaml;
using Ninject.Extensions.Logging;
using Controller.SiteController;

namespace ScUiCore.ViewModels
{
    // ReSharper disable FieldCanBeMadeReadOnly.Local
    // ReSharper disable InconsistentNaming
    // ReSharper disable ConvertToConstant.Local
    // ReSharper disable CompareOfFloatsByEqualityOperator
    #pragma warning disable 649
    public class DemoViewModel
        : ReactiveObject
        , IRoutableViewModel
    {
        ISiteController iController { get; set; }
        ILogger Logger { get; set; }
        Operations Ops { get; set; }

        public DemoViewModel(IScreen screen, Operations ops, ISiteController isiteCtlr, ILogger logger)
        {
            HostScreen = screen;
            Ops = ops;
            iController = isiteCtlr;

            Logger = logger;

            // Collection bound to UI ItemsControl
            TrackModules = new ReactiveCollection<TrackModuleViewModel>();
            TrackModules.CollectionCountChanged
                        .Select(count => count > 0 ? true : false)
                        .ToProperty(this, model => model.ShowHeaderLine);

            // Same collection using different ViewModels
            TenTrackDisplay = new ReactiveCollection<TenTrackModuleViewModel>();
            //TenTrackDisplay.CollectionCountChanged
            //            .Select(count => count > 0 ? true : false)
            //            .ToProperty(this, model => model.ShowTenTrackDisplay);

            SetupHandlerCommands();
            SetupServerUpdates();

            TickNumber = 0xffffffff;    // Initialize for dummy action

            EnabledVm = new MotorCountViewModel(HostScreen, Logger)
            {
                Count = 0,
                TextLabel = "Enabled:"
            };
            DisabledVm = new MotorCountViewModel(HostScreen, Logger)
            {
                Count = 0,
                TextLabel = "Disabled:"
            };
            FaultedVm = new MotorCountViewModel(HostScreen, Logger)
            {
                Count = 0,
                TextLabel = "Faulted:"
            };
            WarningVm = new MotorCountViewModel(HostScreen, Logger)
            {
                Count = 0,
                TextLabel = "Warnings:"
            };
            ShutdownVm = new MotorCountViewModel(HostScreen, Logger)
            {
                Count = 0,
                TextLabel = "Shutdown:"
            };
            ShuttingDownVm = new MotorCountViewModel(HostScreen, Logger)
            {
                Count = 0,
                TextLabel = "ShuttingDown:"
            };
            PrechargingVm = new MotorCountViewModel(HostScreen, Logger)
            {
                Count = 0,
                TextLabel = "Precharging:"
            };
            PrechargedVm = new MotorCountViewModel(HostScreen, Logger)
            {
                Count = 0,
                TextLabel = "Precharged:"
            };
        }

        // IRoutableViewModel implementation

        public IScreen HostScreen { get; private set; }
        public string UrlPathSegment
        {
            get { return "Magplane"; }
        }

        // public 

        object _ActiveScreen = null;
        public object ActiveScreen
        {
            get { return _ActiveScreen; }
            set { this.RaiseAndSetIfChanged(value); }
        }

        public ReactiveCommand SelectScreen { get; private set; }
        public ReactiveCommand ShowKeyboard { get; private set; }
        public ReactiveCommand CmdInitialize { get; private set; }

        // 11-Sep-2013 Dan requested 4 more buttons
        public ReactiveCommand CmdPrecharge { get; private set; }
        public ReactiveCommand CmdBurp { get; private set; }
        public ReactiveCommand CmdDisable { get; private set; }
        public ReactiveCommand CmdClearFaults { get; private set; }

        // properties for binding

        ReactiveCollection<TrackModuleViewModel> _TrackModules;
        public ReactiveCollection<TrackModuleViewModel> TrackModules
        {
            get { return _TrackModules; }
            set { this.RaiseAndSetIfChanged(value); }
        }

        ReactiveCollection<TenTrackModuleViewModel> _TenTrackDisplay;
        public ReactiveCollection<TenTrackModuleViewModel> TenTrackDisplay
        {
            get { return _TenTrackDisplay; }
            set { this.RaiseAndSetIfChanged(value); }
        }

        ObservableAsPropertyHelper<bool> _ShowHeaderLine;
        public bool ShowHeaderLine
        {
            get { return _ShowHeaderLine.Value; }
        }

        bool _ShowTenTrackDisplay = false;
        public bool ShowTenTrackDisplay
        {
            get { return _ShowTenTrackDisplay; }
            set
            {
                this.RaiseAndSetIfChanged(value);
                if (value)
                {
                    // Reset 10-track display
                    ModuleNumber = 5;   // Dummied up track modules start with Id="5"
                    Counter = 0;
                }
            }
        }

        string _Status = "(none)";
        public string Status
        {
            get { return _Status; }
            set { this.RaiseAndSetIfChanged(value); }
        }

        string _Message = "(none)";
        public string Message
        {
            get { return _Message; }
            set { this.RaiseAndSetIfChanged(value); }
        }

        MotorCountViewModel _EnabledVm; //new MotorCountViewModel(HostScreen, Logger);
        public MotorCountViewModel EnabledVm
        {
            get { return _EnabledVm; }
            set { this.RaiseAndSetIfChanged(value); }
        }

        MotorCountViewModel _DisabledVm = null;
        public MotorCountViewModel DisabledVm
        {
            get { return _DisabledVm; }
            set { this.RaiseAndSetIfChanged(value); }
        }

        MotorCountViewModel _FaultedVm = null;
        public MotorCountViewModel FaultedVm
        {
            get { return _FaultedVm; }
            set { this.RaiseAndSetIfChanged(value); }
        }

        MotorCountViewModel _WarningVm = null;
        public MotorCountViewModel WarningVm
        {
            get { return _WarningVm; }
            set { this.RaiseAndSetIfChanged(value); }
        }

        MotorCountViewModel _ShutdownVm = null;
        public MotorCountViewModel ShutdownVm
        {
            get { return _ShutdownVm; }
            set { this.RaiseAndSetIfChanged(value); }
        }

        MotorCountViewModel _ShuttingDownVm = null;
        public MotorCountViewModel ShuttingDownVm
        {
            get { return _ShuttingDownVm; }
            set { this.RaiseAndSetIfChanged(value); }
        }

        MotorCountViewModel _PrechargingVm = null;
        public MotorCountViewModel PrechargingVm
        {
            get { return _PrechargingVm; }
            set { this.RaiseAndSetIfChanged(value); }
        }

        MotorCountViewModel _PrechargedVm = null;
        public MotorCountViewModel PrechargedVm
        {
            get { return _PrechargedVm; }
            set { this.RaiseAndSetIfChanged(value); }
        }

        // Unit test helper
        public uint TickNumber { get; set; }

        // helpers

        // Keep this around, saved on each tick
        MotorStateCountsDto MotorStateCounts { get; set; }

        void SetupHandlerCommands()
        {
            CmdInitialize = new ReactiveCommand ( );
            CmdInitialize.Subscribe ( _ =>
                {
                    try
                    {
                        var result = iController.Initialize();
                        if (!result.CumSuccess)
                        {
                            var err = string.Format("SiteController.Initialize failed:{0}", result.Message);
                            Logger.Error(err);
                            Status = err;
                        }
                    }
                    catch (Exception ex)
                    {
                        var err = string.Format("SiteController.Initialize() exception:{0}", ex.Message);
                        Logger.Error(err);
                        Status = err;
                    }
                } );
        }

        void SetupServerUpdates()
        {
            iController.UiUpdate += ServerUpdate;
        }

        public void DemoUpdate(string message)
        {
            Message = message;
        }

        // TBD Kludge to dummy up some tracks
        ModuleInfoDto[] DummyList()
        {
            var list = new ModuleInfoDto[10];
            var status = new SystemMotorStatusDto
            {
                Faulted = false,
                Warning = false,
                Standby = false,
                Precharging = true,
                Precharged = false,
                Running = false,
                Stopping = false
            };
            for (var i = 0; i < 10; ++i)
                list[i] = new ModuleInfoDto(1.1f * i,
                                            1.25f * i,
                                            (i + 5).ToString(),
                                            "1.2.3." + i,
                                            12.0f,
                                            status,
                                            1.3f * i,
                                            0.768f + (0.21f * i));
            return list;
        }

        TrainInfoDto[] DummyTrains(string moduleName, float position)
        {
            var list = new TrainInfoDto[1];
            for (var k = 0; k < list.Length; ++k)
                list[k] = new TrainInfoDto("Train" + (k + 1), 2.75f + k, moduleName, position, 8.0f, 0.0f, true);
            return list;
        }

        // Dummy stuff:
        int ModuleNumber { get; set; }   // Dummied up track modules start with Id="5"
        int Counter { get; set; }

        // This is our notification from the server that something has changed
        public void ServerUpdate ( uint tickNum, string stateName, MotorStateCountsDto aggregateState, IDictionary<string, string>  motorStatusDisplays )
        {
            var firstTime = (TickNumber == 0xffffffff);

            TickNumber = tickNum;
            //Logger.Info("Server tick event:{0}", TickNumber);

            // Update Site Controller status display
            Status = stateName;

            // 11-Sep-2013, update new motor count information 
            UpdateMotorStatus();

            MotorStateCounts = aggregateState;

            var serverModules = iController.GetModuleInfo();
            if (serverModules.Length == 0)
                serverModules = DummyList();

            if (serverModules.Length < TrackModules.Count)
            {
                Logger.Warn("# of tracks has dropped, clearing & rebuilding our collection");
                TrackModules.Clear(); // Start over. (not sure if this condition makes sesnse or will ever occur
            }

            // For each track module returned from the server, 
            // update or create a corresponding ViewModel
            foreach (var info in serverModules)
            {
                var trackvm = TrackModules.FirstOrDefault(mod => mod.TrackId == info.Id);
                if (trackvm != null)
                {
                    UpdateTrackModuleData(trackvm, info);
                }
                else
                {
                    AddTrackModuleData(info);
                }

                // Same for 10-track display, update/create each ViewModel
                var tenTrack = TenTrackDisplay.FirstOrDefault(mod => mod.TrackId == info.Id);
                if (tenTrack != null)
                {
                    UpdateTrackModuleData(tenTrack, info);
                }
                else
                {
                    AddTenTrackModuleData(info);
                }
            }

            // Update the ten-track train display if it's enabled
            // The 'HasTrain' property on the individual tracks will be updated too
            if (!ShowTenTrackDisplay) return;

            var trains = iController.GetTrainInfo();
            if (trains.Length == 0)
            {
                // Dummy up a moving train if nothing is coming from server
                // tick every 1/4 second, make the dummy train move, 10 ticks per track module
                if (firstTime)
                {
                    // Initialize some things
                    ModuleNumber = 5;   // Dummied up track modules start with Id="5"
                    Counter = 0;
                }

                var positionOnModule = 0.1f * Counter;  // ten ticks to get across a track
                //Debug.WriteLine("PositionOnModule={0:f2}", positionOnModule);
                trains = DummyTrains(ModuleNumber.ToString(), positionOnModule);
                if (Counter == 10)
                {
                    ++ModuleNumber;
                    Counter = -1;
                }
                if (ModuleNumber > 14)
                {
                    ModuleNumber = 5;
                    Counter = -1;
                }
                ++Counter;
            }

            // Show the train info on the ten-track display
            foreach (var train in trains)
            {
                // Look through all our track modules & find desired one
                foreach (var trackvm in TenTrackDisplay)
                {
                    if (train.CurrentModule == trackvm.TrackId)
                    {
                        // On the correct module, if already on this track, update info,
                        // otherwise add train to this track
                        var trainvm = trackvm.TrainsOnModule.FirstOrDefault(mod => mod.Id == train.Id);
                        if (trainvm != null)
                        {
                            UpdateTrainData(trainvm, train, (float)trackvm.Width);
                        }
                        else
                        {
                            AddTrainData(trackvm, train);
                        }
                    }
                    else
                    {
                        // Make sure this train is removed from tracks it's not on
                        var trainvm = trackvm.TrainsOnModule.FirstOrDefault(mod => mod.Id == train.Id);
                        if (trainvm != null)
                        {
                            trackvm.TrainsOnModule.Remove(trainvm);
                        }
                    }
                }

                // Repeat the exercise for the display of individual tracks
                // so that the 'HasTrain' indicator is live
                // Look through all our track modules & find desired one
                foreach (var trackvm in TrackModules)
                {
                    trackvm.HasTrain = (train.CurrentModule == trackvm.TrackId);
                }
            }
        }

        void UpdateMotorStatus()
        {
            try
            {
                EnabledVm.Count = MotorStateCounts.EnabledCount;
                DisabledVm.Count = MotorStateCounts.DisabledCount;
                FaultedVm.Count = MotorStateCounts.FaultedCount;
                WarningVm.Count = MotorStateCounts.WarningCount;
                ShutdownVm.Count = MotorStateCounts.ShutDownCount;
                ShuttingDownVm.Count = MotorStateCounts.ShuttingDownCount;
                PrechargingVm.Count = MotorStateCounts.PrechargingCount;
                PrechargedVm.Count = MotorStateCounts.PrechargedCount;
            }
            catch (Exception ex)
            {
                Logger.Error("SiteController.UpdateMotorStatus() exception:{0}", ex.Message);
            }
        }

        void UpdateTrackModuleData(TrackModuleViewModel trackvm, ModuleInfoDto module)
        {
            trackvm.TrackId = module.Id;	// Better not ever change, it's our collection key ??
            trackvm.WindingLength = module.WindingLength == 0.0f ?
                                                            "(none)" :
                                                            string.Format("{0:f2}", module.WindingLength);
            trackvm.WindingOffset = module.WindingOffset;
            trackvm.MotorStatus = module.MotorStatus.ToString();
            trackvm.ModuleLength = module.ModuleLength;
            trackvm.IpAddress = module.IpAddress;
            trackvm.CommandedVelocity = module.CommandedVelocity;
            trackvm.CommandedForce = module.CommandedForce;
        }

        void AddTrackModuleData(ModuleInfoDto module)
        {
            var trackvm = new TrackModuleViewModel(HostScreen);
            UpdateTrackModuleData(trackvm, module);
            TrackModules.Add(trackvm);
        }

        void UpdateTrackModuleData(TenTrackModuleViewModel trackvm, ModuleInfoDto module)
        {
            trackvm.TrackId = module.Id;	// Better not ever change, it's our collection key ??
            trackvm.WindingLength = module.WindingLength == 0.0f ?
                                                            "(none)" :
                                                            string.Format("{0:f2}", module.WindingLength);
            trackvm.WindingOffset = module.WindingOffset;
            trackvm.MotorStatus = module.MotorStatus.ToString();
            trackvm.ModuleLength = module.ModuleLength;
            trackvm.IpAddress = module.IpAddress;
            trackvm.CommandedVelocity = module.CommandedVelocity;
            trackvm.CommandedForce = module.CommandedForce;
        }

        void AddTenTrackModuleData(ModuleInfoDto module)
        {
            var trackvm = new TenTrackModuleViewModel(HostScreen);
            UpdateTrackModuleData(trackvm, module);
            TenTrackDisplay.Add(trackvm);
        }

        void UpdateTrainData(TrainViewModel trainvm, TrainInfoDto train, float trackModuleWidth)
        {
            trainvm.Id = train.Id;  // better not change!
            trainvm.Acceleration = train.Acceleration;
            trainvm.Forward = train.Forward;
            trainvm.Length = train.Length;
            trainvm.Position = train.PositionInModule;
            trainvm.TrainXPos = train.PositionInModule * (trackModuleWidth > 0.0f ? trackModuleWidth : 1.0f);
        }

        void AddTrainData(TenTrackModuleViewModel trackVm, TrainInfoDto train)
        {
            var trainvm = new TrainViewModel(null, HostScreen);
            UpdateTrainData(trainvm, train, (float)trackVm.Width);
            trackVm.TrainsOnModule.Add(trainvm);
        }
    }
    // ReSharper restore InconsistentNaming
    // ReSharper restore FieldCanBeMadeReadOnly.Local
    // ReSharper restore ConvertToConstant.Local
    // ReSharper restore CompareOfFloatsByEqualityOperator
#pragma warning restore 649
}
