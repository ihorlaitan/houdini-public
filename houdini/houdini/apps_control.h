//
//  apps_control.h
//  Houdini
//
//  Created by Abraham Masri on 11/16/17.
//  Copyright © 2017 Abraham Masri. All rights reserved.
//


#ifndef apps_control_h
#define apps_control_h

#define INSTALLED_APPS_PATH "/private/var/containers/Bundle/Application"
#define APPS_DATA_PATH "/private/var/mobile/Containers/Data/Application"

typedef struct app_dir {
    struct app_dir* next;
    char root_path[150];
    char app_path[190];
    char jdylib_path[210];
    char *display_name;
    char *identifier;
    char *executable;
    boolean_t valid;

} app_dir_t;

void read_apps_data_dir();
void list_applications_installed();

kern_return_t revert_theme_to_original(char *, boolean_t remote_others);

void invalidate_icon_cache(char *);
void uicache();

kern_return_t install_tweak_into_all(const char *, const char *);
kern_return_t apply_theme_into_all(const char *, const char *);
kern_return_t change_icon_badge_color(const char *color_raw, const char *size_type);
kern_return_t change_icons_shape(int radius);

// Utilities
kern_return_t rename_all_icons(const char *, char *);
kern_return_t rename_all_3d_touch_shortcuts(const char *, char *);
kern_return_t apply_passcode_button_theme(char * image_path, char * type);
kern_return_t set_custom_hosts(boolean_t use_custom);
kern_return_t set_emoji_font(char *font_path);
kern_return_t set_bootlogo(char *bootlogo_path);
kern_return_t add_custom_animoji(char *thumbnail_path, char *head_diffuse_path, char *head_AO_path, char *head_SPECROUGHLW_path, char *scnz_file);

void clear_files_for_path(char *);
void apps_control_init(mach_port_t);
#endif /* apps_control_h */
