// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// remap_task.c: guest test of vm_remap with another task as the target.
//
// A task that owns memory maps it into a second task, which the first reaches by the second's task
// port: vm_remap(target = the other task, source = this one). The Core VM server does it to give its
// compile agent the code arena the agent writes compiled kernels into, and Core Image's CPU renderer
// depends on it.
//
// The parent maps a page of its own into a forked child twice. Shared (copy = FALSE) the child reads what
// the parent wrote before and after the mapping, and the parent reads what the child writes. Copied
// (copy = TRUE) the child reads a snapshot and neither sees the other's later writes.
//
// One line per case, "ok" or "FAIL <why>"; exits with the number of failures.
#include <mach/mach.h>
#include <mach/vm_inherit.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

// fork is marked unavailable by the SDK headers of later releases; the device's libSystem has it.
extern pid_t child_fork(void) __asm__("_fork");

static int failures;

static void check(const char *name, int good, const char *why)
{
    if (good) {
        printf("ok   %s\n", name);
    } else {
        printf("FAIL %s: %s\n", name, why);
        failures++;
    }
    fflush(stdout);
}

static int send_word(int fd, uint32_t word)
{
    return write(fd, &word, sizeof word) == (ssize_t)sizeof word;
}

static int receive_word(int fd, uint32_t *word)
{
    return read(fd, word, sizeof *word) == (ssize_t)sizeof *word;
}

// The child: for each address it is sent it answers the two words it finds there, then waits to be told
// to write a word and answers it was done.
static void child_main(int commands, int answers)
{
    uint32_t address;
    while (receive_word(commands, &address) && address != 0) {
        volatile uint32_t *words = (volatile uint32_t *)(uintptr_t)address;
        send_word(answers, words[0]);
        send_word(answers, words[1]);
        uint32_t go;
        receive_word(commands, &go);
        words[2] = 0xc0ffee00U;
        send_word(answers, 1);
        receive_word(commands, &go);
        send_word(answers, words[3]);
    }
    _exit(0);
}

int main(void)
{
    vm_address_t source = 0;
    const vm_size_t size = 0x4000;
    if (vm_allocate(mach_task_self(), &source, size, VM_FLAGS_ANYWHERE) != KERN_SUCCESS) {
        printf("FAIL allocate: vm_allocate\n");
        return 1;
    }
    volatile uint32_t *mine = (volatile uint32_t *)source;
    for (int i = 0; i < 4; i++)
        mine[i] = 0x11110000U + (uint32_t)i;

    int commands[2], answers[2];
    if (pipe(commands) != 0 || pipe(answers) != 0) {
        printf("FAIL pipes\n");
        return 1;
    }
    pid_t child = child_fork();
    if (child == 0) {
        close(commands[1]);
        close(answers[0]);
        child_main(commands[0], answers[1]);
    }
    close(commands[0]);
    close(answers[1]);

    task_t child_task = MACH_PORT_NULL;
    kern_return_t result = task_for_pid(mach_task_self(), child, &child_task);
    check("task port of the child", result == KERN_SUCCESS, "task_for_pid refused");
    if (result != KERN_SUCCESS)
        return failures + 1;

    for (int copy = 0; copy <= 1; copy++) {
        const char *kind = copy ? "copied" : "shared";
        char name[96];
        mine[0] = 0x11110000U;
        mine[1] = 0x11110001U;
        mine[2] = 0;
        mine[3] = 0x11110003U;

        vm_address_t target = 0;
        vm_prot_t current = 0, maximum = 0;
        result = vm_remap(child_task, &target, size, 0, VM_FLAGS_ANYWHERE, mach_task_self(), source, copy ? TRUE : FALSE,
                          &current, &maximum, VM_INHERIT_SHARE);
        snprintf(name, sizeof name, "%s remap into the child", kind);
        char why[96];
        snprintf(why, sizeof why, "vm_remap answered %d", result);
        check(name, result == KERN_SUCCESS && target != 0, why);
        if (result != KERN_SUCCESS)
            continue;
        snprintf(name, sizeof name, "%s protections", kind);
        snprintf(why, sizeof why, "current %d maximum %d", current, maximum);
        check(name, current == (VM_PROT_READ | VM_PROT_WRITE) && maximum == (VM_PROT_READ | VM_PROT_WRITE), why);

        uint32_t first = 0, second = 0, done = 0, late = 0;
        send_word(commands[1], (uint32_t)target);
        receive_word(answers[0], &first);
        receive_word(answers[0], &second);
        snprintf(name, sizeof name, "%s: the child reads the parent's words", kind);
        snprintf(why, sizeof why, "read 0x%x 0x%x", first, second);
        check(name, first == 0x11110000U && second == 0x11110001U, why);

        send_word(commands[1], 1);
        receive_word(answers[0], &done);
        snprintf(name, sizeof name, "%s: the child's write", kind);
        snprintf(why, sizeof why, "the parent reads 0x%x", mine[2]);
        check(name, copy ? mine[2] == 0 : mine[2] == 0xc0ffee00U, why);

        mine[3] = 0x22220003U;
        send_word(commands[1], 1);
        receive_word(answers[0], &late);
        snprintf(name, sizeof name, "%s: the parent's later write", kind);
        snprintf(why, sizeof why, "the child reads 0x%x", late);
        check(name, copy ? late == 0x11110003U : late == 0x22220003U, why);
    }

    send_word(commands[1], 0);
    int status = 0;
    waitpid(child, &status, 0);
    check("the child ended cleanly", WIFEXITED(status) && WEXITSTATUS(status) == 0, "wait status");
    return failures;
}
