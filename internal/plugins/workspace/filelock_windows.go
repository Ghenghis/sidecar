//go:build windows

package workspace

import (
	"fmt"
	"os"
	"path/filepath"
	"syscall"
	"time"
	"unsafe"
)

const (
	lockTimeout       = 5 * time.Second
	lockRetryInterval = 50 * time.Millisecond
)

// Windows LockFileEx flags
const (
	lockfileExclusiveLock   = 0x00000002
	lockfileFailImmediately = 0x00000001
)

var (
	modkernel32      = syscall.NewLazyDLL("kernel32.dll")
	procLockFileEx   = modkernel32.NewProc("LockFileEx")
	procUnlockFileEx = modkernel32.NewProc("UnlockFileEx")
)

// lockFileEx calls the Windows LockFileEx API for real file locking.
// dwFlags: lockfileExclusiveLock for exclusive, 0 for shared.
// Uses lockfileFailImmediately for non-blocking attempts.
func lockFileEx(handle syscall.Handle, flags uint32) error {
	// OVERLAPPED structure with zero offset locks from beginning of file
	var overlapped syscall.Overlapped
	// Lock 1 byte at offset 0 — sufficient for advisory locking
	r1, _, err := procLockFileEx.Call(
		uintptr(handle),
		uintptr(flags),
		0, // reserved, must be zero
		1, // nNumberOfBytesToLockLow
		0, // nNumberOfBytesToLockHigh
		uintptr(unsafe.Pointer(&overlapped)),
	)
	if r1 == 0 {
		return err
	}
	return nil
}

// unlockFileEx calls the Windows UnlockFileEx API.
func unlockFileEx(handle syscall.Handle) error {
	var overlapped syscall.Overlapped
	r1, _, err := procUnlockFileEx.Call(
		uintptr(handle),
		0, // reserved, must be zero
		1, // nNumberOfBytesToUnlockLow
		0, // nNumberOfBytesToUnlockHigh
		uintptr(unsafe.Pointer(&overlapped)),
	)
	if r1 == 0 {
		return err
	}
	return nil
}

// acquireManifestLock acquires a file lock on Windows using LockFileEx.
// This provides real mutual exclusion equivalent to Unix flock().
// exclusive=true for write locks, false for shared read locks.
func acquireManifestLock(path string, exclusive bool) (*os.File, error) {
	lockPath := path + ".lock"

	// Ensure directory exists for lock file
	dir := filepath.Dir(lockPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return nil, err
	}

	lockFile, err := os.OpenFile(lockPath, os.O_CREATE|os.O_RDWR, 0644)
	if err != nil {
		return nil, err
	}

	// Build lock flags: non-blocking + optional exclusive
	flags := uint32(lockfileFailImmediately)
	if exclusive {
		flags |= lockfileExclusiveLock
	}

	// Get the Windows file handle
	handle := syscall.Handle(lockFile.Fd())

	// Try non-blocking lock with timeout (mirrors Unix flock behavior)
	deadline := time.Now().Add(lockTimeout)
	for {
		err := lockFileEx(handle, flags)
		if err == nil {
			return lockFile, nil
		}

		if time.Now().After(deadline) {
			_ = lockFile.Close()
			return nil, fmt.Errorf("lock acquisition timeout after %v", lockTimeout)
		}
		time.Sleep(lockRetryInterval)
	}
}

// releaseManifestLock releases the Windows file lock and closes the file.
func releaseManifestLock(lockFile *os.File) {
	if lockFile == nil {
		return
	}
	handle := syscall.Handle(lockFile.Fd())
	_ = unlockFileEx(handle)
	_ = lockFile.Close()
}
