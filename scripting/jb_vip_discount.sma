/* Sublime AMXX Editor v2.2 */

#include <amxmodx>
#include <vip_core>
#include <jailbreak_core>

#define PLUGIN  "[JB] VIP: Purchase discount"
#define AUTHOR  "Natsheh"

new const Float:g_fVIPDiscount = 0.25;

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);
}

public vip_flag_creation()
{
    register_vip_flag('g', "25% Purchase discount");
}

public client_authorized(id)
{
    if(get_user_vip(id) & read_flags("g"))
    {
        jb_set_user_discount(id, g_fVIPDiscount);
    }
}
