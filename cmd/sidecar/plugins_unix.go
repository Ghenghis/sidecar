//go:build !windows

package main

import (
	"github.com/marcus/sidecar/internal/features"
	"github.com/marcus/sidecar/internal/plugin"
	"github.com/marcus/sidecar/internal/plugins/conversations"
	"github.com/marcus/sidecar/internal/plugins/filebrowser"
	"github.com/marcus/sidecar/internal/plugins/gitstatus"
	"github.com/marcus/sidecar/internal/plugins/notes"
	"github.com/marcus/sidecar/internal/plugins/tdmonitor"
	"github.com/marcus/sidecar/internal/plugins/workspace"
)

// registerPlugins registers all available plugins for Unix platforms (macOS, Linux, WSL).
func registerPlugins(registry *plugin.Registry, logger interface{ Warn(string, ...interface{}) }) {
	// Register plugins (order determines tab order)
	if err := registry.Register(tdmonitor.New()); err != nil {
		logger.Warn("failed to register tdmonitor plugin", "err", err)
	}
	if err := registry.Register(gitstatus.New()); err != nil {
		logger.Warn("failed to register gitstatus plugin", "err", err)
	}
	if err := registry.Register(filebrowser.New()); err != nil {
		logger.Warn("failed to register filebrowser plugin", "err", err)
	}
	if err := registry.Register(conversations.New()); err != nil {
		logger.Warn("failed to register conversations plugin", "err", err)
	}
	if err := registry.Register(workspace.New()); err != nil {
		logger.Warn("failed to register workspace plugin", "err", err)
	}
	if features.IsEnabled("notes_plugin") {
		if err := registry.Register(notes.New()); err != nil {
			logger.Warn("failed to register notes plugin", "err", err)
		}
	}
}
