"""Archive measured contact replays; never hide failed or aggressive cases.
Usage: python tools/compare_contact.py BEFORE.json AFTER.json OUT_DIRECTORY
"""
from pathlib import Path
import csv,gzip,json,sys

def main():
    before,after,out=map(Path,sys.argv[1:]);out.mkdir(parents=True,exist_ok=True)
    data={name:json.loads(path.read_text()) for name,path in [('before',before),('after',after)]}
    assert [r['scenario'] for r in data['before']['results']]==[r['scenario'] for r in data['after']['results']]
    comparison=[]
    for old,new in zip(data['before']['results'],data['after']['results']):
        row={'scenario':new['scenario']}
        for key in ['final_speed_m_s','stop_distance_m','stop_time_s','distance_m','final_body_energy_j','final_energy_j','peak_rear_slip','peak_rear_lateral_m_s','mean_rear_slip_after_1s','peak_load_n','max_hands_after_crash_nm','reported_friction_work_j','collision_impulse_ns','final_lean_deg','crashed']:
            row['before_'+key]=old.get(key);row['after_'+key]=new.get(key)
        comparison.append(row)
    (out/'comparison.json').write_text(json.dumps(comparison,indent=2)+'\n')
    with (out/'comparison.csv').open('w') as stream:
        writer=csv.DictWriter(stream,fieldnames=list(comparison[0]),lineterminator='\n');writer.writeheader();writer.writerows(comparison)
    for name,run in data.items():
        (out/(name+'-results.json')).write_text(json.dumps(run['results'],indent=2)+'\n')
        with gzip.open(out/(name+'-trace.json.gz'),'wt',compresslevel=6) as stream:json.dump(run,stream,separators=(',',':'))
    for r in comparison:print(r['scenario'],r['before_stop_distance_m'],r['after_stop_distance_m'],r['before_max_hands_after_crash_nm'],r['after_max_hands_after_crash_nm'])
if __name__=='__main__':main()
